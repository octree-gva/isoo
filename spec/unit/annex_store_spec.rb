# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'

RSpec.describe AnnexStore do
  it 'versions annex files' do
    Dir.mktmpdir do |tmp|
      store = AnnexStore.new(tmp)
      id = store.create_annex(title: 'Architectural schema')
      f1 = store.upload(annex_id: id, uploaded_file: 'png1', original_name: 'd.png', document_version: '0.1.1')
      f2 = store.upload(annex_id: id, uploaded_file: 'png2', original_name: 'd2.png', document_version: '0.1.2')
      expect(f1).to eq("#{id}-architectural-schema-1.png")
      expect(f2).to eq("#{id}-architectural-schema-2.png")
      expect(store.latest_file(id)['filename']).to eq(f2)
      expect(store.file_for_document_version(id, '0.1.1')['filename']).to eq(f1)
    end
  end

  it 'creates annex with empty title using slug fallback' do
    Dir.mktmpdir do |tmp|
      store = AnnexStore.new(tmp)
      id = store.create_annex(title: '', slug: 'network-diagram')
      reg = YAML.safe_load_file(File.join(tmp, 'annexes', 'registry.yaml'))
      entry = reg['annexes'].find { |a| a['id'] == id }
      expect(entry['slug']).to eq('network-diagram')
    end
  end

  it 'finds annex by slug' do
    Dir.mktmpdir do |tmp|
      store = AnnexStore.new(tmp)
      id = store.create_annex(title: 'Annex 1', slug: 'annex-1')
      expect(store.find_by_slug('annex-1')['id']).to eq(id)
      expect(store.find_by_slug('missing')).to be_nil
    end
  end

  it 'returns nil from find_by_slug when no registry exists yet' do
    Dir.mktmpdir do |tmp|
      store = AnnexStore.new(tmp)
      expect(store.find_by_slug('annex-1')).to be_nil
      expect(File.file?(File.join(tmp, 'annexes', 'registry.yaml'))).to be(true)
    end
  end
end
