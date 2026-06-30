# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'

RSpec.describe FileStore do
  it 'reads and writes under root' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('a/b.txt', 'hello')
      expect(store.read('a/b.txt')).to eq('hello')
    end
  end

  it 'rejects traversal' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      expect { store.read('../etc/passwd') }.to raise_error(ArgumentError)
    end
  end
end
