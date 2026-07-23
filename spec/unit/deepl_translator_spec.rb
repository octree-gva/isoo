# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe DeepLTranslator do
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

  describe '.configured?' do
    it 'is false without an API key' do
      expect(described_class.configured?).to be(false)
    end

    it 'is true when DEEPL_API_KEY is set' do
      ENV['DEEPL_API_KEY'] = 'test-key'
      expect(described_class.configured?).to be(true)
    end
  end

  describe '.translate' do
    it 'passes through text when not configured' do
      expect(described_class.translate('Hello', context: 'ctx')).to eq('Hello')
    end

    it 'passes through empty text when configured' do
      ENV['DEEPL_API_KEY'] = 'test-key'
      expect(described_class.translate('', context: 'ctx')).to eq('')
      expect(described_class.translate('   ', context: 'ctx')).to eq('   ')
    end

    it 'calls DeepL with context when configured for French' do
      ENV['DEEPL_API_KEY'] = 'test-key'
      response = instance_double('DeepL::TextResult', text: 'Bonjour')
      allow(described_class).to receive(:ensure_auth!)
      expect(DeepL).to receive(:translate).with('Hello', nil, 'FR', context: 'project: Test').and_return(response)

      result = described_class.translate('Hello', context: 'project: Test')
      expect(result).to eq('Bonjour')
    end
  end

  describe '.context_for' do
    it 'builds context from document metadata' do
      doc = { 'doc_id' => 'policy', 'title' => 'Policy' }
      meta = { 'iso27001' => { 'classification' => 'Public', 'version' => '0.1.0' } }

      context = described_class.context_for(doc: doc, meta: meta, project_name: 'Acme')
      expect(context).to include('project: Acme', 'doc_id: policy', 'title: Policy',
                                 'classification: Public', 'version: 0.1.0')
    end
  end
end
