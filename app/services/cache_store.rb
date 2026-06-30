# frozen_string_literal: true

require_relative 'cache/file_fingerprint'
require_relative 'cache/null_store'
require_relative 'cache/memory_store'
require_relative 'cache/memcached_store'

class CacheStore
  def self.build
    server = ENV.fetch('MEMCACHE_SERVER', '').strip
    return Cache::NullStore.new if server.empty?

    Cache::MemcachedStore.new(
      server: server,
      namespace: ENV.fetch('MEMCACHE_NAMESPACE', 'isoo')
    )
  end

  def self.file_fingerprint(path)
    Cache::FileFingerprint.call(path)
  end
end
