# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'

RSpec.describe TableDocumentStore do
  it 'adds and soft-deletes rows' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('tables/t/t.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, "# Table\n"))
      store.write('tables/t/t.schema.yaml', {
        'columns' => [{ 'key' => 'name', 'label' => 'Name' }]
      }.to_yaml)
      store.write('tables/t/t.csv', "name,_row_id,_deleted_at\n")

      tds = TableDocumentStore.new(store)
      row = tds.add_row('tables/t', { 'name' => 'Alice' })
      expect(tds.read('tables/t')[:rows].length).to eq(1)

      tds.soft_delete('tables/t', row['_row_id'])
      expect(tds.read('tables/t')[:rows]).to be_empty
    end
  end

  it 'updates an existing row' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('tables/t/t.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, "# Table\n"))
      store.write('tables/t/t.schema.yaml', {
        'columns' => [{ 'key' => 'name', 'label' => 'Name' }]
      }.to_yaml)
      store.write('tables/t/t.csv', "name,_row_id,_deleted_at\n")

      tds = TableDocumentStore.new(store)
      row = tds.add_row('tables/t', { 'name' => 'Alice' })
      tds.update_row('tables/t', row['_row_id'], { 'name' => 'Alicia' })

      expect(tds.read('tables/t')[:rows].first['name']).to eq('Alicia')
    end
  end

  it 'saves rows with version bump' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('tables/t/t.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, "# Table\n"))
      store.write('tables/t/t.schema.yaml', { 'columns' => [{ 'key' => 'name', 'label' => 'Name' }] }.to_yaml)
      store.write('tables/t/t.csv', "name,_row_id,_deleted_at\n")

      tds = TableDocumentStore.new(store)
      rows = [{ 'name' => 'Bob', '_row_id' => '1', '_deleted_at' => '' }]
      tds.save_rows('tables/t', rows: rows, version: '0.2.0', date: '2026-01-01', author: 'x', changes: 'add row')
      meta, = FrontMatter.parse(store.read('tables/t/t.md'))
      expect(meta.dig('iso27001', 'version')).to eq('0.2.0')
    end
  end

  it 'rejects non-https links' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('tables/t/t.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, "# Table\n"))
      store.write('tables/t/t.schema.yaml', {
        'columns' => [{ 'key' => 'url', 'label' => 'URL', 'type' => 'link' }]
      }.to_yaml)
      store.write('tables/t/t.csv', "url,_row_id,_deleted_at\n")

      tds = TableDocumentStore.new(store)
      expect { tds.add_row('tables/t', { 'url' => 'http://example.com' }) }
        .to raise_error(TableDocumentStore::ValidationError, IsooI18n.t('table.link_https_required'))
    end
  end

  it 'rejects review dates that are not in the future' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('tables/t/t.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, "# Table\n"))
      store.write('tables/t/t.schema.yaml', {
        'columns' => [{ 'key' => 'due', 'label' => 'Due', 'type' => 'review_date' }]
      }.to_yaml)
      store.write('tables/t/t.csv', "due,_row_id,_deleted_at\n")

      tds = TableDocumentStore.new(store)
      expect { tds.add_row('tables/t', { 'due' => Date.today.iso8601 }) }
        .to raise_error(TableDocumentStore::ValidationError, IsooI18n.t('table.review_date_must_be_future'))
    end
  end

  it 'normalizes empty switch values to off' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('tables/t/t.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, "# Table\n"))
      store.write('tables/t/t.schema.yaml', {
        'columns' => [{ 'key' => 'active', 'label' => 'Active', 'type' => 'switch', 'default' => false }]
      }.to_yaml)
      store.write('tables/t/t.csv', "active,_row_id,_deleted_at\n")

      tds = TableDocumentStore.new(store)
      row = tds.add_row('tables/t', {})
      expect(row['active']).to eq('0')
    end
  end

  it 'saves fullscreen row edits and bumps version' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('tables/t/t.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, "# Table\n"))
      store.write('tables/t/t.schema.yaml', {
        'columns' => [{ 'key' => 'name', 'label' => 'Name' }]
      }.to_yaml)
      store.write('tables/t/t.csv', "name,_row_id,_deleted_at\n")

      tds = TableDocumentStore.new(store)
      row = tds.add_row('tables/t', { 'name' => 'Alice' })
      tds.save_fullscreen(
        'tables/t',
        rows_params: { row['_row_id'] => { 'name' => 'Alicia' } },
        version: '0.2.0',
        date: '2026-02-01',
        author: 'tester',
        changes: 'bulk edit'
      )

      expect(tds.read('tables/t')[:rows].first['name']).to eq('Alicia')
      meta, body = FrontMatter.parse(store.read('tables/t/t.md'))
      expect(meta.dig('iso27001', 'version')).to eq('0.2.0')
      expect(body).to include('bulk edit')
    end
  end
end
