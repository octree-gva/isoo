# frozen_string_literal: true

require 'csv'
require 'fileutils'
require 'yaml'

require_relative '../spec_helper'

RSpec.describe OwnerFieldsMigrator do
  let(:tmpdir) { Dir.mktmpdir('owner-migrate') }

  after { FileUtils.rm_rf(tmpdir) }

  it 'appends owner columns to table schemas and CSV rows' do
    doc_dir = File.join(tmpdir, 'registers', 'demo-register')
    FileUtils.mkdir_p(doc_dir)
    File.write(File.join(doc_dir, 'demo-register.schema.yaml'), {
      'schema_version' => '1',
      'kind' => 'table',
      'primary_key' => 'name',
      'columns' => [{ 'key' => 'name', 'label' => 'Name', 'type' => 'text' }],
      '_internal' => [{ 'key' => '_row_id', 'type' => 'uuid' }, { 'key' => '_deleted_at', 'type' => 'datetime' }]
    }.to_yaml)
    File.write(File.join(doc_dir, 'demo-register.csv'), <<~CSV)
      name,_row_id,_deleted_at
      GDPR,row-1,
    CSV

    migrator = described_class.new(tmpdir).migrate!

    schema = YAML.safe_load_file(File.join(doc_dir, 'demo-register.schema.yaml'))
    keys = schema['columns'].map { |col| col['key'] }
    expect(keys).to eq(%w[name owner_name owner_email])

    rows = CSV.read(File.join(doc_dir, 'demo-register.csv'), headers: true)
    expect(rows.headers).to eq(%w[name owner_name owner_email _row_id _deleted_at])
    expect(rows.first['owner_name']).to eq('')
    expect(rows.first['owner_email']).to eq('')
    expect(migrator.updated_schemas).to eq(1)
    expect(migrator.updated_csvs).to eq(1)
  end
end
