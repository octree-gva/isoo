# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ProjectManifest do
  it 'normalizes nil forms and responses to empty arrays' do
    manifest = described_class.new('/tmp/manifest.yaml', {
                                     'name' => 'Empty',
                                     'documents' => nil,
                                     'forms' => nil
                                   })

    expect(manifest.documents).to eq([])
    expect(manifest.forms).to eq([])
  end

  it 'normalizes nil responses on each form' do
    manifest = described_class.new('/tmp/manifest.yaml', {
                                     'name' => 'Demo',
                                     'documents' => [],
                                     'forms' => [{ 'doc_id' => 'audit', 'path' => 'audit/x', 'responses' => nil }]
                                   })

    expect(manifest.forms.first['responses']).to eq([])
  end
end
