# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe AnnexAssetName do
  it 'builds export labels from doc id and document version' do
    expect(described_class.label(doc_id: 'architectural-schema', document_version: '0.3.0'))
      .to eq('Version 0.3.0 — architectural-schema')
  end

  it 'falls back to file version when document version is missing' do
    expect(described_class.label(doc_id: 'diagram', file_version: 2))
      .to eq('Version 2 — diagram')
  end

  it 'builds download filenames from slug and stored extension' do
    expect(described_class.download_filename(slug: 'architectural-schema',
                                             stored_filename: '1-architectural-schema-3.png'))
      .to eq('architectural-schema.png')
  end
end
