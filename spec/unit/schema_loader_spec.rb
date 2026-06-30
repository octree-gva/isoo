# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'

RSpec.describe SchemaLoader do
  it 'loads valid text schema' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('s.schema.yaml', { 'kind' => 'text', 'sections' => [] }.to_yaml)
      loader = SchemaLoader.new(store, File.join(__dir__, '../../spec/document.schema.json'))
      expect(loader.load('s.schema.yaml')['kind']).to eq('text')
    end
  end

  it 'rejects invalid schema' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('s.schema.yaml', { 'kind' => 'text' }.to_yaml)
      loader = SchemaLoader.new(store, File.join(__dir__, '../../spec/document.schema.json'))
      expect { loader.load('s.schema.yaml') }.to raise_error(ArgumentError)
    end
  end
end
