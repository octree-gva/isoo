# frozen_string_literal: true

require_relative '../spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe ProjectExporter do
  def write_doc(root, path, doc_id, body:, classification: 'Public', csv: nil)
    dir = File.join(root, path)
    FileUtils.mkdir_p(dir)
    basename = File.basename(path)
    meta = {
      'iso27001' => { 'doc_id' => doc_id, 'classification' => classification, 'version' => '0.1.0' }
    }
    File.write(File.join(dir, "#{basename}.md"), FrontMatter.dump(meta, body))
    return unless csv

    File.write(File.join(dir, "#{basename}.csv"), csv)
  end

  it 'exports all documents including confidential ones' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'public-doc', 'title' => 'Public Doc', 'path' => 'docs/public-doc' },
          { 'doc_id' => 'secret-doc', 'title' => 'Secret Doc', 'path' => 'docs/secret-doc' }
        ]
      }.to_yaml)
      write_doc(tmp, 'docs/public-doc', 'public-doc', body: "# Hello\n")
      write_doc(tmp, 'docs/secret-doc', 'secret-doc', body: "# Secret\n", classification: 'Confidential')

      body = described_class.new(tmp).export_markdown
      expect(body).to include('Public Doc', 'Hello', 'Secret Doc', 'Secret')
    end
  end

  it 'renders html entries with tables and rewritten links' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'overview', 'title' => 'Overview', 'path' => 'docs/overview' },
          { 'doc_id' => 'register', 'title' => 'Register', 'path' => 'docs/register' }
        ]
      }.to_yaml)
      write_doc(tmp, 'docs/overview', 'overview', body: "See [register](./register/register.md).\n\n**Bold** text.\n")
      write_doc(tmp, 'docs/register', 'register', body: "# Register\n", csv: "name,value\nRow,1\n")
      File.write(File.join(tmp, 'docs/register', 'register.schema.yaml'), {
        'kind' => 'table',
        'columns' => [
          { 'key' => 'name', 'label' => 'Entry name' },
          { 'key' => 'value', 'label' => 'Amount' }
        ]
      }.to_yaml)

      body = described_class.new(tmp).export_markdown
      expect(body).to include('| name | value |', '| --- | --- |', '| Row | 1 |')
      expect(body).not_to include('name,value')

      entries = described_class.new(tmp).html_entries
      overview = entries.find { |entry| entry['doc_id'] == 'overview' }
      register = entries.find { |entry| entry['doc_id'] == 'register' }

      expect(overview['body_html']).to include('<strong>Bold</strong>')
      expect(overview['body_html']).to include('href="#register"')
      expect(overview['group']).to eq('Documents')
      expect(register['table_html']).to include('<table class="export-table">', 'Entry name', 'Amount', 'Row')
      expect(register['table_html']).not_to include('_row_id', '_deleted_at')
    end
  end

  it 'uses document title as h1 and demotes body headings in markdown export' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'policy', 'title' => 'IS 04 Policy', 'path' => 'docs/policy', 'seq' => 1 }
        ]
      }.to_yaml)
      write_doc(tmp, 'docs/policy', 'policy', body: "# Policy Title\n\n## Purpose\n\nText.\n")

      body = described_class.new(tmp).export_markdown
      expect(body).to include('# IS 04 Policy', '## Policy Title', '### Purpose', 'Text.')
    end
  end

  it 'sorts export entries with annexes and form responses after main documents' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'policy', 'title' => 'Policy', 'path' => 'policies/policy', 'seq' => 1 }
        ],
        'annexes' => [
          { 'doc_id' => 'diagram', 'title' => 'Diagram', 'path' => 'annexes/diagram', 'kind' => 'file_annex',
            'seq' => 900 }
        ],
        'forms' => [
          {
            'doc_id' => 'audit-form',
            'title' => 'Audit Form',
            'path' => 'audit/audit-form',
            'response_kind' => 'text',
            'responses' => [
              { 'doc_id' => 'audit-form-1', 'title' => 'Audit 1',
                'path' => 'audit/audit-form/responses/audit-form-1' }
            ]
          }
        ]
      }.to_yaml)
      write_doc(tmp, 'policies/policy', 'policy', body: "Policy\n")
      write_doc(tmp, 'annexes/diagram', 'diagram', body: "Diagram\n")
      write_doc(tmp, 'audit/audit-form/responses/audit-form-1', 'audit-form-1', body: "Audit\n")

      ids = described_class.new(tmp).entries.map { |e| e.doc['doc_id'] }
      expect(ids).to eq(%w[policy diagram audit-form-1])

      html_entries = described_class.new(tmp).html_entries
      expect(html_entries.map { |e| e['export_tier'] }).to eq(%w[main annex form])
    end
  end

  it 'includes version control html and omits schema sections from html entries' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'register', 'title' => 'Register', 'path' => 'registers/register', 'seq' => 1 }
        ]
      }.to_yaml)
      body = VersionControlWriter.append_row(
        "# Register\n\n# Schema\n\nSee schema.\n",
        version: '0.1.0',
        date: '2026-01-01',
        author: 'owner',
        changes: 'created'
      )
      write_doc(tmp, 'registers/register', 'register', body: body, csv: "name,value\nRow,1\n")
      File.write(File.join(tmp, 'registers/register', 'register.schema.yaml'), {
        'kind' => 'table',
        'columns' => [
          { 'key' => 'name', 'label' => 'Name', 'description' => 'Entry name.' },
          { 'key' => 'value', 'label' => 'Value' }
        ]
      }.to_yaml)

      entry = described_class.new(tmp).html_entries.first
      expect(entry['version_control_html']).to include('Document Version Control', '0.1.0')
      expect(entry['body_html']).not_to include('Demo seed rows')
      expect(entry['table_legend_html']).to include('export-table-legend', 'Entry name.', 'export-legend-undocumented')
      expect(entry['body_html']).to include('Register')
      expect(entry['body_html']).not_to include('Schema')
      expect(entry['has_data_table']).to be(true)
    end
  end

  it 'filters export entries by export tag scope' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'overview', 'title' => 'Overview', 'path' => 'context/overview', 'seq' => 1 },
          { 'doc_id' => 'ropa', 'title' => 'ROPA', 'path' => 'context/ropa', 'seq' => 2 }
        ]
      }.to_yaml)
      write_doc(tmp, 'context/overview', 'overview', body: "# Overview\n")
      write_doc(tmp, 'context/ropa', 'ropa', body: "# ROPA\n")
      File.write(File.join(tmp, 'context/overview', 'overview.schema.yaml'), {
        'kind' => 'text',
        'export_tags' => %w[basic]
      }.to_yaml)
      File.write(File.join(tmp, 'context/ropa', 'ropa.schema.yaml'), {
        'kind' => 'text',
        'export_tags' => %w[data_protection]
      }.to_yaml)

      all_ids = described_class.new(tmp).entries.map { |entry| entry.doc['doc_id'] }
      basic_ids = described_class.new(tmp, export_scope: 'basic').entries.map { |entry| entry.doc['doc_id'] }

      expect(all_ids).to eq(%w[overview ropa])
      expect(basic_ids).to eq(%w[overview])
    end
  end

  it 'filters annex entries by asset export tag scope' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'annexes' => [
          { 'doc_id' => 'diagram', 'title' => 'Diagram', 'path' => 'annexes/diagram', 'kind' => 'file_annex' },
          { 'doc_id' => 'policy', 'title' => 'Policy', 'path' => 'annexes/policy', 'kind' => 'file_annex' }
        ]
      }.to_yaml)
      write_doc(tmp, 'annexes/diagram', 'diagram', body: "# Diagram\n")
      write_doc(tmp, 'annexes/policy', 'policy', body: "# Policy\n")
      File.write(File.join(tmp, 'annexes/diagram', 'diagram.schema.yaml'), {
        'kind' => 'file_annex',
        'export_tags' => %w[soi]
      }.to_yaml)
      File.write(File.join(tmp, 'annexes/policy', 'policy.schema.yaml'), {
        'kind' => 'file_annex',
        'export_tags' => %w[basic]
      }.to_yaml)

      scoped_ids = described_class.new(tmp, export_scope: 'soi').entries.map do |entry|
        entry.doc['doc_id']
      end

      expect(scoped_ids).to eq(%w[diagram])
    end
  end

  it 'omits soft-deleted annexes from all export scopes' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'annexes' => [
          { 'doc_id' => 'active', 'title' => 'Active', 'path' => 'annexes/active', 'kind' => 'file_annex' },
          { 'doc_id' => 'gone', 'title' => 'Gone', 'path' => 'annexes/gone', 'kind' => 'file_annex',
            '_deleted_at' => '2026-06-28T12:00:00Z' }
        ]
      }.to_yaml)
      write_doc(tmp, 'annexes/active', 'active', body: "# Active\n")
      write_doc(tmp, 'annexes/gone', 'gone', body: "# Gone\n")

      ids = described_class.new(tmp, export_scope: 'full').entries.map { |entry| entry.doc['doc_id'] }

      expect(ids).to eq(%w[active])
    end
  end

  it 'includes version control html for documents without an in-body version block' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'overview', 'title' => 'Overview', 'path' => 'context/overview', 'seq' => 1 }
        ]
      }.to_yaml)
      write_doc(tmp, 'context/overview', 'overview', body: "# Overview\n")
      File.write(File.join(tmp, 'context/overview', 'overview.audit.yaml'), {
        'version' => '0.1.0',
        'modified_at' => '2026-06-29T11:53:46Z',
        'modified_by' => 'owner@example.com'
      }.to_yaml)

      entry = described_class.new(tmp).html_entries.first

      expect(entry['version_control_html']).to include('Document Version Control', '0.1.0', 'owner@example.com')
    end
  end

  it 'loads export entries without orphan version rows in the body' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'assets', 'title' => 'Assets', 'path' => 'context/assets', 'seq' => 1 }
        ]
      }.to_yaml)
      body = <<~MD
        # Document Version Control

        | Version | Last Modified | Last Modified By | Document Changes |
        |---------|---------------|------------------|------------------|
        | 0.1.0 | 2026-06-29 | seed@isoo.local | Document first created |
        | 0.2.0 | 2026-06-29 | seed@isoo.local | Demo seed rows |
        | 0.3.0 | 2026-06-29 | editor | updated |
        | 0.2.0 | 2026-06-29 | seed@isoo.local | Demo seed rows |

        | 0.2.0 | 2026-06-29 | seed@isoo.local | Demo seed rows |
        | 0.3.0 | 2026-06-29 | editor | updated |
      MD
      write_doc(tmp, 'context/assets', 'assets', body: body, csv: "asset_no,_row_id,_deleted_at\nA1,rid-1,\n")
      File.write(File.join(tmp, 'context/assets', 'assets.schema.yaml'), {
        'kind' => 'table',
        'columns' => [
          { 'key' => 'asset_no', 'label' => 'Asset No.' }
        ]
      }.to_yaml)

      entry = described_class.new(tmp).entries.first

      expect(entry.body.strip).to eq('')
      expect(entry.version_control_html.scan('Demo seed rows').size).to eq(1)

      html_entry = described_class.new(tmp).html_entries.first
      expect(html_entry['table_html']).to include('<th>Asset No.</th>')
      expect(html_entry['table_html']).not_to include('_row_id', '_deleted_at')
      expect(html_entry['body_html']).not_to include('Demo seed rows')
    end
  end

  def seed_annex_files(root, annex_id:, slug:, png_bytes: 'png')
    files_dir = File.join(root, 'annexes', 'files')
    FileUtils.mkdir_p(files_dir)
    File.write(File.join(files_dir, "#{annex_id}-#{slug}-1.png"), png_bytes)
    File.write(File.join(root, 'annexes', 'registry.yaml'), {
      'next_id' => annex_id + 1,
      'annexes' => [{ 'id' => annex_id, 'slug' => slug, 'title' => slug.tr('-', ' ').capitalize }]
    }.to_yaml)
    File.write(File.join(root, 'annexes', 'versions.yaml'), {
      'annexes' => {
        annex_id.to_s => {
          'latest' => 1,
          'versions' => [{
            'version' => 1,
            'filename' => "#{annex_id}-#{slug}-1.png",
            'original_name' => 'upload.png',
            'uploaded_at' => '2026-01-01T00:00:00Z',
            'document_version' => '0.1.0'
          }]
        }
      }
    }.to_yaml)
  end

  it 'rewrites annex bbcode, embeds referenced assets, and bypasses annex tag scope' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'overview', 'title' => 'Overview', 'path' => 'context/overview', 'seq' => 1 }
        ],
        'annexes' => [
          { 'doc_id' => 'diagram', 'title' => 'Diagram', 'path' => 'annexes/diagram', 'kind' => 'file_annex' }
        ]
      }.to_yaml)
      write_doc(tmp, 'context/overview', 'overview', body: "See [ANNEX diagram].\n")
      File.write(File.join(tmp, 'context/overview', 'overview.schema.yaml'), {
        'kind' => 'text',
        'export_tags' => %w[basic]
      }.to_yaml)
      write_doc(tmp, 'annexes/diagram', 'diagram', body: "# Diagram\n")
      File.write(File.join(tmp, 'annexes/diagram', 'diagram.schema.yaml'), {
        'kind' => 'file_annex',
        'export_tags' => %w[soi]
      }.to_yaml)
      meta = YAML.safe_load_file(File.join(tmp, 'annexes/diagram', 'diagram.md'))
      meta['iso27001']['annex_id'] = 1
      File.write(File.join(tmp, 'annexes/diagram', 'diagram.md'), FrontMatter.dump(meta, "# Diagram\n"))
      seed_annex_files(tmp, annex_id: 1, slug: 'diagram')

      markdown = described_class.new(tmp, export_scope: 'basic').export_markdown
      expect(markdown).to include('[Diagram](#annex-ref-diagram)')
      expect(markdown).to include('## Referenced annex assets')
      expect(markdown).to include('id="annex-ref-diagram"')
      expect(markdown).to include('data:image/png;base64,')

      html_entry = described_class.new(tmp, export_scope: 'basic').html_entries.first
      expect(html_entry['body_html']).to include('href="#annex-ref-diagram"')
      expect(html_entry['annex_assets_html']).to include('id="annex-ref-diagram"')
      expect(html_entry['annex_assets_html']).to include('class="export-annex-figure"')

      annex_ids = described_class.new(tmp, export_scope: 'basic').entries.map { |entry| entry.doc['doc_id'] }
      expect(annex_ids).to eq(%w[overview])
    end
  end
end
