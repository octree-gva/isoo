# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe AnnexDocumentStore do
  it 'persists export tags on the annex schema' do
    Dir.mktmpdir do |tmp|
      path = 'annexes/diagram'
      FileUtils.mkdir_p(File.join(tmp, path))
      schema_path = File.join(tmp, path, 'diagram.schema.yaml')
      File.write(schema_path, { 'kind' => 'file_annex', 'description' => 'old' }.to_yaml)
      File.write(File.join(tmp, path, 'diagram.md'), FrontMatter.dump({
                                                                        'title' => 'Diagram',
                                                                        'iso27001' => {
                                                                          'schema' => 'diagram.schema.yaml',
                                                                          'version' => '0.1.0'
                                                                        }
                                                                      }, 'body'))

      store = AnnexDocumentStore.new(FileStore.new(tmp))
      store.save_metadata(
        path,
        title: 'Diagram',
        description: 'Network map',
        version: '0.2.0',
        date: '2026-06-28',
        author: 'editor@example.com',
        changes: 'Tagged for export',
        export_tags: %w[soi]
      )

      schema = YAML.safe_load_file(schema_path)
      expect(schema['export_tags']).to eq(%w[soi])
      expect(schema['description']).to eq('Network map')
    end
  end
end
