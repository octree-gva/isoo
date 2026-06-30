# frozen_string_literal: true

require 'tmpdir'
require_relative '../spec_helper'

RSpec.describe ProjectManifest do
  let(:cache) { Cache::MemoryStore.new(namespace: 'test') }
  let(:root) { Dir.mktmpdir }
  let(:path) { File.join(root, 'manifest.yaml') }

  before do
    allow(Container).to receive(:cache).and_return(cache)
    File.write(path, { 'name' => 'Demo', 'documents' => [] }.to_yaml)
  end

  after { FileUtils.rm_rf(root) }

  it 'avoids rereading manifest from disk on cache hit' do
    reads = 0
    original = File.method(:read)
    allow(File).to receive(:read) do |read_path, *|
      reads += 1 if read_path == path
      original.call(read_path, encoding: 'UTF-8')
    end

    described_class.load(root)
    described_class.load(root)
    expect(reads).to eq(1)
  end

  it 'reloads after save bumps the project scope' do
    manifest = described_class.load(root)
    manifest.data['name'] = 'Renamed'
    manifest.save!

    reloaded = described_class.load(root)
    expect(reloaded.name).to eq('Renamed')
  end

  it 'derives project scope from manifest path' do
    project_path = File.join(root, 'projects', 'acme', 'manifest.yaml')
    FileUtils.mkdir_p(File.dirname(project_path))
    File.write(project_path, { 'name' => 'Acme' }.to_yaml)
    expect(described_class.project_scope(project_path)).to eq('project:acme')
  end
end
