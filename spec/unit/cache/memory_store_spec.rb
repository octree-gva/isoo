# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Cache::MemoryStore do
  subject(:store) { described_class.new(namespace: 'test') }

  it 'is enabled' do
    expect(store.enabled?).to be true
  end

  it 'returns cached values within the same scope version' do
    calls = 0
    value = store.fetch('doc:1', scope: 'project:demo') do
      calls += 1
      'alpha'
    end
    expect(value).to eq('alpha')
    expect(store.fetch('doc:1', scope: 'project:demo') { calls += 1 }).to eq('alpha')
    expect(calls).to eq(1)
  end

  it 'isolates keys by scope' do
    store.fetch('doc:1', scope: 'project:a') { 'a' }
    expect(store.fetch('doc:1', scope: 'project:b') { 'b' }).to eq('b')
  end

  it 'invalidates cached entries for a scope after bump' do
    calls = 0
    store.fetch('doc:1', scope: 'project:demo') do
      calls += 1
      'v1'
    end
    store.bump('project:demo')
    expect(store.fetch('doc:1', scope: 'project:demo') do
      calls += 1
      'v2'
    end).to eq('v2')
    expect(calls).to eq(2)
  end

  it 'does not invalidate other scopes when one scope is bumped' do
    store.fetch('doc:1', scope: 'project:a') { 'a' }
    store.bump('project:b')
    expect(store.fetch('doc:1', scope: 'project:a') { 'new-a' }).to eq('a')
  end

  it 'expires entries when expires_in elapses' do
    calls = 0
    store.fetch('doc:1', scope: 'project:demo', expires_in: 1) do
      calls += 1
      'fresh'
    end
    sleep 1.01
    expect(store.fetch('doc:1', scope: 'project:demo', expires_in: 1) do
      calls += 1
      'new'
    end).to eq('new')
    expect(calls).to eq(2)
  end

  it 'deletes a single key' do
    store.fetch('doc:1', scope: 'project:demo') { 'keep' }
    store.delete('doc:1', scope: 'project:demo')
    expect(store.fetch('doc:1', scope: 'project:demo') { 'again' }).to eq('again')
  end
end
