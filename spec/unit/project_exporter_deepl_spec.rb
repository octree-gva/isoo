# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ProjectExporter do
  around do |example|
    original = ENV.fetch('DEEPL_API_KEY', nil)
    ENV.delete('DEEPL_API_KEY')
    example.run
  ensure
    if original.nil?
      ENV.delete('DEEPL_API_KEY')
    else
      ENV['DEEPL_API_KEY'] = original
    end
  end

  def write_doc(root, path, doc_id, body:)
    dir = File.join(root, path)
    FileUtils.mkdir_p(dir)
    basename = File.basename(path)
    meta = { 'iso27001' => { 'doc_id' => doc_id, 'classification' => 'Public', 'version' => '0.1.0' } }
    File.write(File.join(dir, "#{basename}.md"), FrontMatter.dump(meta, body))
  end

  it 'does not translate when export_lang is en' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [{ 'doc_id' => 'overview', 'title' => 'Overview', 'path' => 'docs/overview' }]
      }.to_yaml)
      write_doc(tmp, 'docs/overview', 'overview', body: "# Hello\n")

      allow(DeepLTranslator).to receive(:translate).and_return('translated')

      body = described_class.new(tmp, export_lang: 'en').export_markdown
      expect(body).to include('# Overview', 'Hello')
      expect(DeepLTranslator).not_to have_received(:translate)
    end
  end

  it 'translates body and title when export_lang is fr and DeepL is configured' do
    ENV['DEEPL_API_KEY'] = 'test-key'
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [{ 'doc_id' => 'overview', 'title' => 'Overview', 'path' => 'docs/overview' }]
      }.to_yaml)
      write_doc(tmp, 'docs/overview', 'overview', body: "# Hello\n")

      allow(DeepLTranslator).to receive(:translate) do |text, **|
        text.to_s.include?('Overview') ? 'Aperçu' : 'Bonjour'
      end

      body = described_class.new(tmp, export_lang: 'fr').export_markdown
      expect(body).to include('# Aperçu', 'Bonjour')
      expect(DeepLTranslator).to have_received(:translate).at_least(:twice)
    end
  end

  it 'ignores export_lang fr when DeepL is not configured' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [{ 'doc_id' => 'overview', 'title' => 'Overview', 'path' => 'docs/overview' }]
      }.to_yaml)
      write_doc(tmp, 'docs/overview', 'overview', body: "# Hello\n")

      allow(DeepLTranslator).to receive(:translate)

      body = described_class.new(tmp, export_lang: 'fr').export_markdown
      expect(body).to include('# Overview', 'Hello')
      expect(DeepLTranslator).not_to have_received(:translate)
    end
  end
end
