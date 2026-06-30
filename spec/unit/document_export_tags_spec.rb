# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe DocumentExportTags do
  it 'reads export tags from a document schema' do
    Dir.mktmpdir do |tmp|
      schema_dir = File.join(tmp, 'context/overview')
      FileUtils.mkdir_p(schema_dir)
      File.write(File.join(schema_dir, 'overview.schema.yaml'), {
        'kind' => 'text',
        'export_tags' => %w[basic soi]
      }.to_yaml)

      doc = { 'doc_id' => 'overview', 'path' => 'context/overview' }
      store = FileStore.new(tmp)

      expect(described_class.for_doc(doc, store: store)).to eq(%w[basic soi])
      expect(described_class.matches?(doc, scope: 'basic', store: store)).to be(true)
      expect(described_class.matches?(doc, scope: 'data_protection', store: store)).to be(false)
    end
  end

  it 'inherits export tags from the parent form for responses' do
    Dir.mktmpdir do |tmp|
      form_dir = File.join(tmp, 'plans/incident-form')
      FileUtils.mkdir_p(form_dir)
      File.write(File.join(form_dir, 'incident-form.schema.yaml'), {
        'kind' => 'form',
        'response_kind' => 'text',
        'export_tags' => %w[data_protection]
      }.to_yaml)

      manifest = ProjectManifest.new(File.join(tmp, 'manifest.yaml'), {
                                       'forms' => [{
                                         'doc_id' => 'incident-form',
                                         'path' => 'plans/incident-form',
                                         'responses' => [{
                                           'doc_id' => 'incident-form-1',
                                           'path' => 'plans/incident-form/responses/incident-form-1'
                                         }]
                                       }]
                                     })
      doc = {
        'doc_id' => 'incident-form-1',
        'path' => 'plans/incident-form/responses/incident-form-1',
        'form_id' => 'incident-form'
      }
      store = FileStore.new(tmp)

      expect(described_class.for_doc(doc, store: store, manifest: manifest)).to eq(%w[data_protection])
    end
  end
end
