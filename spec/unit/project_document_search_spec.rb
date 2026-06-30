# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'
require 'securerandom'

RSpec.describe ProjectDocumentSearch do
  def write_text_doc(store, path, title:, body:)
    store.write(OkfPaths.md(path), FrontMatter.dump(
                                     { 'title' => title, 'iso27001' => { 'version' => '0.1.0' } },
                                     body
                                   ))
    store.write(OkfPaths.schema(path), {
      'sections' => [
        { 'key' => 'purpose', 'label' => 'Purpose', 'level' => 'h2', 'role' => 'body', 'editable' => true }
      ]
    }.to_yaml)
  end

  def write_table_doc(store, path, title:, rows:)
    store.write(OkfPaths.md(path), FrontMatter.dump(
                                     { 'title' => title, 'iso27001' => { 'version' => '0.1.0' } },
                                     "# #{title}\n"
                                   ))
    store.write(OkfPaths.schema(path), {
      'kind' => 'table',
      'primary_key' => 'name',
      'columns' => [{ 'key' => 'name', 'label' => 'Name', 'type' => 'text' }]
    }.to_yaml)
    csv = CSV.generate do |out|
      out << %w[name _row_id _deleted_at]
      rows.each { |row| out << [row[:name], SecureRandom.uuid, ''] }
    end
    store.write(OkfPaths.csv(path), csv)
  end

  it 'finds text and table documents matching the query' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      write_text_doc(store, 'docs/overview', title: 'Overview',
                                             body: "## Purpose\n\nWe use Squarespace for marketing.\n")
      write_table_doc(store, 'docs/licenses', title: 'Licence Register', rows: [{ name: 'Microsoft 365' }])

      manifest = ProjectManifest.new(File.join(tmp, 'manifest.yaml'), {
                                       'name' => 'Test',
                                       'documents' => [
                                         { 'doc_id' => 'overview', 'path' => 'docs/overview', 'kind' => 'text',
                                           'title' => 'Overview' },
                                         { 'doc_id' => 'licenses', 'path' => 'docs/licenses', 'kind' => 'table',
                                           'title' => 'Licence Register' }
                                       ]
                                     })

      hits = described_class.new(manifest: manifest, store: store, slug: 'demo').search('Squarespace')
      expect(hits.map(&:doc_id)).to eq(['overview'])
      expect(hits.first.snippet).to include('Squarespace')
      expect(hits.first.url).to eq('/projects/demo/docs/overview')
    end
  end

  it 'requires all terms to match' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      write_table_doc(store, 'docs/licenses', title: 'Licence Register',
                                              rows: [{ name: 'Squarespace CMS' }])

      manifest = ProjectManifest.new(File.join(tmp, 'manifest.yaml'), {
                                       'name' => 'Test',
                                       'documents' => [
                                         { 'doc_id' => 'licenses', 'path' => 'docs/licenses', 'kind' => 'table',
                                           'title' => 'Licence Register' }
                                       ]
                                     })

      expect(described_class.new(manifest: manifest, store: store, slug: 'demo').search('Squarespace').size).to eq(1)
      expect(described_class.new(manifest: manifest, store: store,
                                 slug: 'demo').search('Squarespace CMS').size).to eq(1)
      expect(described_class.new(manifest: manifest, store: store,
                                 slug: 'demo').search('Squarespace WordPress').size).to eq(0)
    end
  end

  it 'returns no hits for blank queries' do
    manifest = ProjectManifest.new('/tmp/manifest.yaml', { 'name' => 'Test', 'documents' => [] })
    store = FileStore.new(Dir.mktmpdir)
    hits = described_class.new(manifest: manifest, store: store, slug: 'demo').search('   ')
    expect(hits).to eq([])
  end
end
