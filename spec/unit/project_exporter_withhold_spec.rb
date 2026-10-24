# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ProjectExporter do
  def write_doc(root, path, doc_id, body:, withheld: false, export_tags: [])
    dir = File.join(root, path)
    FileUtils.mkdir_p(dir)
    basename = File.basename(path)
    meta = { 'iso27001' => { 'doc_id' => doc_id, 'classification' => 'Public', 'version' => '0.1.0' } }
    meta['iso27001']['withheld'] = true if withheld
    File.write(File.join(dir, "#{basename}.md"), FrontMatter.dump(meta, body))
    schema = { 'kind' => 'text', 'sections' => [] }
    schema['export_tags'] = export_tags if export_tags.any?
    File.write(File.join(dir, "#{basename}.schema.yaml"), schema.to_yaml)
  end

  it 'omits withheld documents from full export' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'visible', 'title' => 'Visible', 'path' => 'docs/visible' },
          { 'doc_id' => 'secret', 'title' => 'Secret', 'path' => 'docs/secret' }
        ]
      }.to_yaml)
      write_doc(tmp, 'docs/visible', 'visible', body: "# Visible\n")
      write_doc(tmp, 'docs/secret', 'secret', body: "# Secret\n", withheld: true)

      body = described_class.new(tmp, export_scope: 'full').export_markdown
      expect(body).to include('Visible')
      expect(body).not_to include('Secret')
    end
  end

  it 'omits withheld documents from tagged export' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'soi-doc', 'title' => 'SOI Doc', 'path' => 'docs/soi-doc' },
          { 'doc_id' => 'withheld-soi', 'title' => 'Withheld SOI', 'path' => 'docs/withheld-soi' }
        ]
      }.to_yaml)
      write_doc(tmp, 'docs/soi-doc', 'soi-doc', body: "# SOI\n", export_tags: %w[soi])
      write_doc(tmp, 'docs/withheld-soi', 'withheld-soi', body: "# Hidden\n", withheld: true, export_tags: %w[soi])

      body = described_class.new(tmp, export_scope: 'soi').export_markdown
      expect(body).to include('SOI Doc')
      expect(body).not_to include('Withheld SOI')
      expect(body).not_to include('Hidden')
    end
  end

  it 'returns nil for single-document export of withheld doc' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [{ 'doc_id' => 'secret', 'title' => 'Secret', 'path' => 'docs/secret' }]
      }.to_yaml)
      write_doc(tmp, 'docs/secret', 'secret', body: "# Secret\n", withheld: true)

      exporter = described_class.new(tmp)
      expect(exporter.entry_for('secret')).to be_nil
      expect(exporter.export_markdown_doc('secret')).to eq('')
    end
  end

  it 'does not embed a withheld annex referenced from a visible document' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'policy', 'title' => 'Policy', 'path' => 'docs/policy', 'kind' => 'text' },
          { 'doc_id' => 'diagram', 'title' => 'Diagram', 'path' => 'annexes/diagram', 'kind' => 'file_annex' }
        ],
        'annexes' => [
          { 'doc_id' => 'diagram', 'title' => 'Diagram', 'path' => 'annexes/diagram', 'kind' => 'file_annex' }
        ]
      }.to_yaml)
      write_doc(tmp, 'docs/policy', 'policy', body: "See [ANNEX diagram]\n")
      write_doc(tmp, 'annexes/diagram', 'diagram', body: "# Diagram\n", withheld: true)

      body = described_class.new(tmp, export_scope: 'full').export_markdown
      expect(body).to include('Policy')
      expect(body).not_to include('## Referenced')
    end
  end
end
