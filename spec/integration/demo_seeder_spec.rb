# frozen_string_literal: true

require_relative '../spec_helper'
require 'fileutils'

RSpec.describe DemoSeeder do
  it 'populates text and table demo data' do
    data = App::DATA_PATH
    git = GitService.new(data)
    slug = "seed-test-#{SecureRandom.hex(3)}"
    ProjectCreator.new(data_root: data, git: git).create(
      name: 'Seed Test', slug: slug, author: 'seed@test.local'
    )

    seeder = described_class.new(data_root: data, git: git)
    expect(seeder.populate(slug: slug, author: 'seed@test.local')).to eq(:populated)
    expect(seeder.populate(slug: slug, author: 'seed@test.local')).to eq(:skipped)

    store = ClassifiedFileStore.new(FileStore.new(File.join(data, 'projects', slug)))
    overview = TextDocumentStore.new(store).read('context/organisation-overview')
    expect(overview[:fields]['about_us']).to include('Acme Open Source')
    expect(overview[:version_control_rows]).to be_empty
    expect(overview[:meta].dig('iso27001', 'version')).to eq('0.1.0')

    legal = TableDocumentStore.new(store).read('context/legal-and-contractual-requirements-register')
    expect(legal[:rows].length).to eq(2)
    expect(legal[:meta].dig('iso27001', 'version')).to eq('0.1.0')
    legal_path = OkfPaths.md('context/legal-and-contractual-requirements-register')
    expect(VersionControlWriter.existing_rows(store.read(legal_path))).to be_empty

    manifest = ProjectManifest.load(File.join(data, 'projects', slug))
    expect(manifest.annexes.map { |a| a['doc_id'] }).to contain_exactly('architectural-schema', 'network-diagram')
    schema = YAML.safe_load(store.read(OkfPaths.schema('annexes/architectural-schema'))) || {}
    expect(schema['export_tags']).to eq(%w[soi])
  ensure
    FileUtils.rm_rf(File.join(data, 'projects', slug)) if slug
  end
end
