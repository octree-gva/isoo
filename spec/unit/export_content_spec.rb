# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ExportContent do
  it 'renders version control as an HTML table' do
    body = VersionControlWriter.append_row(
      '',
      version: '0.1.0',
      date: '2026-01-01',
      author: 'auditor',
      changes: 'Document first created'
    )

    html = described_class.version_control_table_html(body)

    expect(html).to include('Document Version Control')
    expect(html).to include('<th>Version</th>', '<th>Last Modified</th>')
    expect(html).to include('0.1.0', 'auditor', 'Document first created')
  end

  it 'renders version control from metadata when the body has no version block' do
    html = described_class.version_control_table_html(
      "# Overview\n",
      current_version: '0.1.0',
      meta: { 'iso27001' => { 'version' => '0.1.0' }, 'timestamp' => '2026-06-29T10:00:00Z' },
      audit: { 'version' => '0.1.0', 'modified_at' => '2026-06-29T11:53:46Z', 'modified_by' => 'owner@example.com' }
    )

    expect(html).to include('Document Version Control', '0.1.0', 'owner@example.com', 'Document first created')
  end

  it 'always renders the version control table structure' do
    html = described_class.version_control_table_html('# Body only')

    expect(html).to include('Document Version Control', '<table class="export-table export-version-table">')
    expect(html).to include('<tbody></tbody>')
  end

  it 'emphasises the current version row in export HTML' do
    body = VersionControlWriter.append_row(
      '',
      version: '0.1.0',
      date: '2026-01-01',
      author: 'auditor',
      changes: 'Document first created'
    )
    body = VersionControlWriter.append_row(
      body, version: '0.2.0', date: '2026-02-01', author: 'editor', changes: 'Updated scope'
    )

    html = described_class.version_control_table_html(body, current_version: '0.2.0')

    expect(html).to include('export-version-row--current')
    expect(html).to include('0.2.0', 'Updated scope')
  end

  it 'deduplicates repeated version rows in export HTML' do
    body = <<~MD
      # Document Version Control

      | Version | Last Modified | Last Modified By | Document Changes |
      |---------|---------------|------------------|------------------|
      | 0.1.0 | 2026-06-29 | seed@isoo.local | Document first created |
      | 0.2.0 | 2026-06-29 | seed@isoo.local | Demo seed rows |
      | 0.3.0 | 2026-06-29 | editor | updated |
      | 0.2.0 | 2026-06-29 | seed@isoo.local | Demo seed rows |
    MD

    html = described_class.version_control_table_html(body, current_version: '0.3.0')

    expect(html.scan('Demo seed rows').size).to eq(1)
    expect(html.scan('0.2.0').size).to eq(1)
  end

  it 'strips leading orphan version rows from markdown bodies' do
    body = "| 0.2.0 | 2026-06-29 | seed@isoo.local | Demo seed rows |\n| 0.3.0 | 2026-06-29 | editor | updated |\n"

    expect(described_class.strip_leading_version_rows(body)).to eq('')
  end

  it 'renders a definition list legend for table columns' do
    schema = {
      'kind' => 'table',
      'columns' => [
        { 'key' => 'name', 'label' => 'Name', 'description' => 'Supplier name.' },
        { 'key' => 'notes', 'label' => 'Notes', 'description' => '' }
      ]
    }

    html = described_class.table_legend_html(schema, csv_headers: %w[name notes _row_id])

    expect(html).to include('<dl class="export-legend-list">')
    expect(html).to include('<dt>Name</dt>', '<dd>Supplier name.</dd>')
    expect(html).to include('<dt>Notes</dt>', 'export-legend-undocumented')
    expect(html).not_to include('_row_id')
  end

  it 'strips schema appendix from markdown bodies' do
    body = "# Purpose\n\nText.\n\n# Schema\n\nSee schema file.\n"

    expect(described_class.strip_schema_section(body)).to eq("# Purpose\n\nText.")
  end

  it 'renders export tables without internal columns or deleted rows' do
    schema = {
      'kind' => 'table',
      'columns' => [
        { 'key' => 'name', 'label' => 'Name' },
        { 'key' => 'value', 'label' => 'Value' }
      ]
    }
    csv = "name,value,_row_id,_deleted_at\nActive,1,rid-1,\nGone,2,rid-2,2026-01-01T00:00:00Z\n"

    html = described_class.csv_to_html(csv, schema: schema)

    expect(html).to include('<th>Name</th>', '<th>Value</th>')
    expect(html).not_to include('_row_id', '_deleted_at', 'Gone')
    expect(html).to include('Active', '1')
  end

  it 'omits deleted rows from markdown tables' do
    csv = "name,value,_row_id,_deleted_at\nActive,1,rid-1,\nGone,2,rid-2,2026-01-01T00:00:00Z\n"

    md = described_class.csv_to_markdown(csv)

    expect(md).to include('| Active | 1 |')
    expect(md).not_to include('Gone')
    expect(md).not_to include('_row_id')
  end
end
