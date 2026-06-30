# frozen_string_literal: true

require_relative '../spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe ExportLinkResolver do
  let(:manifest_data) do
    {
      'name' => 'Test',
      'documents' => [
        { 'doc_id' => 'register', 'path' => 'registers/access-register' },
        { 'doc_id' => 'process', 'path' => 'documents/access-process' }
      ],
      'forms' => []
    }
  end

  it 'rewrites relative markdown links to in-export anchors' do
    manifest = ProjectManifest.new('/tmp/manifest.yaml', manifest_data)
    resolver = described_class.build(manifest, exported_doc_ids: %w[register process])

    md = 'See [register](../../registers/access-register/access-register.md).'
    expect(resolver.rewrite_markdown(md)).to include('](#register)')
  end

  it 'leaves external links unchanged' do
    manifest = ProjectManifest.new('/tmp/manifest.yaml', manifest_data)
    resolver = described_class.build(manifest, exported_doc_ids: %w[register])

    md = 'Visit [site](https://example.com/docs).'
    expect(resolver.rewrite_markdown(md)).to eq(md)
  end
end
