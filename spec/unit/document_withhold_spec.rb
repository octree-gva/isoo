# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe DocumentWithhold do
  it 'reads and writes withheld on meta' do
    meta = { 'iso27001' => { 'classification' => 'Internal' } }
    expect(described_class.from_meta(meta)).to be(false)

    described_class.write_to_meta!(meta, true)
    expect(meta.dig('iso27001', 'withheld')).to be(true)
    expect(described_class.from_meta(meta)).to be(true)

    described_class.write_to_meta!(meta, false)
    expect(meta.dig('iso27001', 'withheld')).to be_nil
  end

  it 'detects withheld documents via store' do
    Dir.mktmpdir do |tmp|
      dir = File.join(tmp, 'docs/overview')
      FileUtils.mkdir_p(dir)
      meta = { 'iso27001' => { 'withheld' => true, 'version' => '0.1.0' } }
      File.write(File.join(dir, 'overview.md'), FrontMatter.dump(meta, "# Hi\n"))
      store = FileStore.new(tmp)
      doc = { 'doc_id' => 'overview', 'path' => 'docs/overview' }

      expect(described_class.document_withheld?(doc, store: store)).to be(true)
    end
  end

  it 'stores form withhold on the manifest entry' do
    Dir.mktmpdir do |tmp|
      path = File.join(tmp, 'manifest.yaml')
      File.write(path, {
        'name' => 'T',
        'forms' => [{ 'doc_id' => 'audit', 'path' => 'audit/audit', 'responses' => [] }]
      }.to_yaml)
      manifest = ProjectManifest.new(path, YAML.safe_load_file(path))
      described_class.set_form_withheld!(manifest, 'audit', withheld: true)
      reloaded = ProjectManifest.new(path, YAML.safe_load_file(path))
      expect(described_class.document_withheld?(reloaded.find_form('audit'), store: FileStore.new(tmp))).to be(true)
    end
  end
end
