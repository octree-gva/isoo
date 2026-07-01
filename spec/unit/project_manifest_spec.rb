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

  it 'defaults project version to 0.0.0' do
    manifest = described_class.new('/tmp/manifest.yaml', { 'name' => 'ACME Open Source' })
    expect(manifest.version).to eq('0.0.0')
    expect(manifest.export_title).to eq('ACME Open Source v0.0.0')
    expect(manifest.export_basename).to eq('acme-open-source-v0.0.0')
  end

  it 'bumps project version on save' do
    path = File.join(Dir.mktmpdir, 'manifest.yaml')
    manifest = described_class.new(path, { 'name' => 'Demo', 'version' => '0.0.0' })
    manifest.bump_version!(significant: false)
    expect(manifest.version).to eq('0.0.1')
    manifest.bump_version!(significant: true)
    expect(manifest.version).to eq('0.1.0')
  end

  it 'persists semver version when loading a manifest without a version key' do
    path = File.join(Dir.mktmpdir, 'manifest.yaml')
    File.write(path, { 'name' => 'Voca', 'documents' => [] }.to_yaml)

    manifest = described_class.load(path, cache: Cache::NullStore.new)
    expect(manifest.version).to eq('0.0.0')
    expect(YAML.safe_load_file(path)['version']).to eq('0.0.0')
  end

  it 'migrates legacy integer project versions to semver' do
    path = File.join(Dir.mktmpdir, 'manifest.yaml')
    File.write(path, { 'name' => 'Voca', 'version' => 2, 'documents' => [] }.to_yaml)

    manifest = described_class.load(path, cache: Cache::NullStore.new)
    expect(manifest.version).to eq('0.0.2')
    expect(manifest.export_title).to eq('Voca v0.0.2')
    expect(manifest.export_basename).to eq('voca-v0.0.2')
  end
end
