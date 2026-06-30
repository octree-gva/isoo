# frozen_string_literal: true

require 'securerandom'
require_relative '../spec_helper'

RSpec.describe Cache::MemcachedStore do
  before { ENV['MEMCACHE_SERVER'] = ENV.fetch('MEMCACHE_SERVER', 'memcached:11211') }

  it 'stores and bumps scoped keys against a live memcached' do
    server = ENV.fetch('MEMCACHE_SERVER', '').strip
    skip 'MEMCACHE_SERVER not set' if server.empty?

    scope = "project:integration-#{SecureRandom.hex(4)}"
    key = "live-key-#{SecureRandom.hex(4)}"
    store = described_class.new(server: server, namespace: "isoo-test-#{Process.pid}")
    probe = "probe-#{SecureRandom.hex(4)}"
    probe_calls = 0
    store.fetch(probe, scope: 'global') { probe_calls += 1 }
    store.fetch(probe, scope: 'global') { probe_calls += 1 }
    skip 'memcached unavailable' if probe_calls == 2

    calls = 0
    expect(store.fetch(key, scope: scope) do
      calls += 1
      'ok'
    end).to eq('ok')
    expect(store.fetch(key, scope: scope) { calls += 1 }).to eq('ok')
    expect(calls).to eq(1)

    store.bump(scope)
    expect(store.fetch(key, scope: scope) do
      calls += 1
      'fresh'
    end).to eq('fresh')
    expect(calls).to eq(2)
  end
end
