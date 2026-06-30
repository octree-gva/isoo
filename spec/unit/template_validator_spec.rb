# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml'
require_relative '../spec_helper'

RSpec.describe TemplateValidator do
  it 'accepts a minimal valid bundle' do
    Dir.mktmpdir do |tmp|
      doc_dir = File.join(tmp, 'docs', 'sample')
      FileUtils.mkdir_p(doc_dir)
      File.write(File.join(tmp, 'manifest.yaml'), {
        'documents' => [{ 'doc_id' => 'sample', 'path' => 'docs/sample', 'kind' => 'text' }]
      }.to_yaml)
      File.write(File.join(doc_dir, 'sample.md'), "# Sample\n")
      File.write(File.join(doc_dir, 'sample.schema.yaml'), {
        'schema_version' => '1', 'kind' => 'text', 'sections' => []
      }.to_yaml)

      expect(described_class.new(tmp)).to be_valid
    end
  end

  it 'accepts a form bundle' do
    Dir.mktmpdir do |tmp|
      doc_dir = File.join(tmp, 'docs', 'sample')
      FileUtils.mkdir_p(doc_dir)
      File.write(File.join(tmp, 'manifest.yaml'), {
        'documents' => [{
          'doc_id' => 'sample', 'path' => 'docs/sample', 'kind' => 'form',
          'response_kind' => 'text', 'title' => 'Sample'
        }]
      }.to_yaml)
      File.write(File.join(doc_dir, 'sample.md'), "# Sample\n")
      File.write(File.join(doc_dir, 'sample.schema.yaml'), {
        'schema_version' => '1', 'kind' => 'form', 'response_kind' => 'text', 'sections' => []
      }.to_yaml)

      expect(described_class.new(tmp)).to be_valid
    end
  end
end
