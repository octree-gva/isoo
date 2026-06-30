# frozen_string_literal: true

require 'tmpdir'
require_relative '../spec_helper'

RSpec.describe CachingClassifiedFileStore do
  let(:cache) { Cache::MemoryStore.new(namespace: 'test') }
  let(:root) { Dir.mktmpdir }
  let(:base) { ClassifiedFileStore.new(FileStore.new(root)) }
  let(:store) { described_class.new(base, cache: cache, scope: 'project:demo') }

  after { FileUtils.rm_rf(root) }

  it 'caches reads until the scope is bumped' do
    base.write('doc.md', 'hello', classification: 'Internal', audit: {})
    reads = 0
    allow(base).to receive(:read).and_wrap_original do |method, *args|
      reads += 1
      method.call(*args)
    end

    2.times { expect(store.read('doc.md')).to eq('hello') }
    expect(reads).to eq(1)

    store.write('doc.md', 'updated', classification: 'Internal', audit: {})
    expect(store.read('doc.md')).to eq('updated')
    expect(reads).to eq(2)
  end

  it 'uses encrypted file fingerprint when present' do
    base.write('secret.md', 'classified', classification: 'Confidential', audit: {})
    key_path = store.send(:physical_path, 'secret.md')
    expect(key_path).to end_with('secret.md.enc')
  end
end
