# frozen_string_literal: true

require_relative '../spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe MarkdownExporter do
  it 'exports project markdown' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [{ 'doc_id' => 'd1', 'title' => 'Doc 1', 'path' => 'docs/d1' }]
      }.to_yaml)
      FileUtils.mkdir_p(File.join(tmp, 'docs', 'd1'))
      File.write(File.join(tmp, 'docs', 'd1', 'd1.md'), FrontMatter.dump({}, "# Content\n"))

      body = MarkdownExporter.new(tmp).export
      expect(body).to include('Test export')
      expect(body).to include('Doc 1')
      expect(body).to include('Content')
    end
  end
end
