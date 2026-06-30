# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ExportTagAssigner do
  it 'assigns export tags to template schemas' do
    Dir.mktmpdir do |tmp|
      bundle = File.join(tmp, 'bundle')
      FileUtils.mkdir_p(File.join(bundle, 'context/overview'))
      File.write(File.join(bundle, 'export_tags.yaml'), {
        'tags' => [
          { 'id' => 'basic', 'label' => 'Basic', 'description' => 'Basic docs' },
          { 'id' => 'soi', 'label' => 'SOI', 'description' => 'SOI docs' },
          { 'id' => 'data_protection', 'label' => 'Data Protection', 'description' => 'DPO docs' }
        ]
      }.to_yaml)
      File.write(File.join(bundle, 'manifest.yaml'), {
        'documents' => [{
          'doc_id' => 'organisation-overview',
          'path' => 'context/overview',
          'kind' => 'text'
        }]
      }.to_yaml)
      File.write(File.join(bundle, 'context/overview/overview.schema.yaml'), {
        'kind' => 'text',
        'sections' => []
      }.to_yaml)

      assigner = described_class.new(bundle)
      assigner.sync!

      schema = YAML.safe_load_file(File.join(bundle, 'context/overview/overview.schema.yaml'))
      expect(schema['export_tags']).to include('basic', 'soi')
    end
  end
end
