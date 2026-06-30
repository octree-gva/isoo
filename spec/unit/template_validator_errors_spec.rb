# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml'
require_relative '../spec_helper'

RSpec.describe TemplateValidator do
  it 'reports missing table csv' do
    Dir.mktmpdir do |tmp|
      doc_dir = File.join(tmp, 'registers', 'items')
      FileUtils.mkdir_p(doc_dir)
      File.write(File.join(tmp, 'manifest.yaml'), {
        'documents' => [{ 'doc_id' => 'items', 'path' => 'registers/items', 'kind' => 'table' }]
      }.to_yaml)
      File.write(File.join(doc_dir, 'items.md'), "# Items\n")
      File.write(File.join(doc_dir, 'items.schema.yaml'), {
        'schema_version' => '1',
        'kind' => 'table',
        'primary_key' => 'name',
        'columns' => [{ 'key' => 'name', 'label' => 'Name', 'type' => 'text' }],
        '_internal' => [
          { 'key' => '_row_id', 'type' => 'uuid' },
          { 'key' => '_deleted_at', 'type' => 'datetime' }
        ]
      }.to_yaml)

      validator = described_class.new(tmp)
      expect(validator).not_to be_valid
      expect(validator.errors.join).to include('missing csv')
    end
  end
end
