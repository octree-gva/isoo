# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe CacheStore do
  after { Container.reset! }

  it 'builds a null store when MEMCACHE_SERVER is unset' do
    ENV.delete('MEMCACHE_SERVER')
    expect(described_class.build).to be_a(Cache::NullStore)
  end

  it 'builds a null store when MEMCACHE_SERVER is blank' do
    ENV['MEMCACHE_SERVER'] = '   '
    expect(described_class.build).to be_a(Cache::NullStore)
  end

  it 'builds a memcached store when MEMCACHE_SERVER is set' do
    ENV['MEMCACHE_SERVER'] = 'memcached:11211'
    ENV['MEMCACHE_NAMESPACE'] = 'isoo-test'
    expect(described_class.build).to be_a(Cache::MemcachedStore)
  end
end
