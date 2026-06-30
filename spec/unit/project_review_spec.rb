# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'

RSpec.describe ProjectReview do
  let(:manifest) do
    ProjectManifest.new('/tmp/manifest.yaml', {
                          'documents' => [
                            { 'doc_id' => 'policy', 'path' => 'policies/policy', 'kind' => 'text',
                              'title' => 'Policy' },
                            { 'doc_id' => 'register', 'path' => 'registers/register', 'kind' => 'table',
                              'title' => 'Register' }
                          ],
                          'forms' => []
                        })
  end

  def write_text_doc(store, path, timestamp:, version_date:)
    body = VersionControlWriter.append_row(
      "# Policy\n\nBody",
      version: '0.1.0',
      date: version_date,
      author: 'tester',
      changes: 'created'
    )
    meta = {
      'title' => 'Policy',
      'timestamp' => timestamp,
      'iso27001' => { 'version' => '0.1.0' }
    }
    store.write(OkfPaths.md(path), FrontMatter.dump(meta, body))
  end

  def write_table_doc(store, path)
    store.write(OkfPaths.md(path), FrontMatter.dump({ 'title' => 'Register', 'timestamp' => '2026-01-01T00:00:00Z' },
                                                    "# Register\n"))
    store.write(OkfPaths.schema(path), {
      'schema_version' => '1',
      'kind' => 'table',
      'primary_key' => 'name',
      'columns' => [
        { 'key' => 'name', 'label' => 'Name', 'type' => 'text' },
        { 'key' => 'next_review', 'label' => 'Next review', 'type' => 'review_date' }
      ],
      '_internal' => [{ 'key' => '_row_id', 'type' => 'uuid' }, { 'key' => '_deleted_at', 'type' => 'datetime' }]
    }.to_yaml)
    store.write(OkfPaths.csv(path), "name,next_review,_row_id,_deleted_at\nAcme,2024-01-01,rid-1,\n")
  end

  it 'lists documents not updated within 12 months' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      write_text_doc(store, 'policies/policy', timestamp: '2023-01-01T00:00:00Z', version_date: '2023-01-01')
      write_table_doc(store, 'registers/register')

      review = described_class.new(manifest: manifest, store: ClassifiedFileStore.new(store))
      stale = review.stale_documents(as_of: Date.new(2026, 6, 1))

      expect(stale.map(&:doc_id)).to eq(['policy'])
      expect(stale.first.last_updated).to eq(Date.new(2023, 1, 1))
    end
  end

  it 'lists the oldest editable text and table documents' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      write_text_doc(store, 'policies/policy', timestamp: '2023-01-01T00:00:00Z', version_date: '2023-01-01')
      write_table_doc(store, 'registers/register')

      review = described_class.new(manifest: manifest, store: ClassifiedFileStore.new(store))
      oldest = review.oldest_editable_documents

      expect(oldest.map(&:doc_id)).to eq(%w[policy register])
      expect(oldest.first.last_updated).to eq(Date.new(2023, 1, 1))
    end
  end

  it 'returns at most five oldest editable documents' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      docs = (1..6).map do |n|
        path = "docs/doc#{n}"
        write_text_doc(store, path, timestamp: "202#{n}-01-01T00:00:00Z", version_date: "202#{n}-01-01")
        { 'doc_id' => "doc#{n}", 'path' => path, 'kind' => 'text', 'title' => "Doc #{n}" }
      end
      six_doc_manifest = ProjectManifest.new('/tmp/manifest.yaml', { 'documents' => docs, 'forms' => [] })

      review = described_class.new(manifest: six_doc_manifest, store: ClassifiedFileStore.new(store))
      oldest = review.oldest_editable_documents

      expect(oldest.length).to eq(5)
      expect(oldest.map(&:doc_id)).to eq(%w[doc1 doc2 doc3 doc4 doc5])
    end
  end

  it 'lists expired review_date values from tables' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      write_text_doc(store, 'policies/policy', timestamp: '2026-01-01T00:00:00Z', version_date: '2026-01-01')
      write_table_doc(store, 'registers/register')

      review = described_class.new(manifest: manifest, store: ClassifiedFileStore.new(store))
      expired = review.expired_review_dates(as_of: Date.new(2026, 6, 1))

      expect(expired.length).to eq(1)
      expect(expired.first).to have_attributes(
        doc_id: 'register',
        row_label: 'Acme',
        review_date: Date.new(2024, 1, 1),
        days_overdue: 882
      )
    end
  end
end
