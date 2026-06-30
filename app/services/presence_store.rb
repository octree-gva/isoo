# frozen_string_literal: true

require_relative 'presence/memory_backend'
require_relative 'presence/memcached_backend'

class PresenceStore
  def self.build
    server = ENV.fetch('MEMCACHE_SERVER', '').strip
    backend = if server.empty?
                Presence::MemoryBackend.new
              else
                Presence::MemcachedBackend.new(
                  server: server,
                  namespace: ENV.fetch('MEMCACHE_NAMESPACE', 'isoo')
                )
              end
    new(backend)
  end

  def initialize(backend)
    @backend = backend
  end

  def memcached?
    @backend.is_a?(Presence::MemcachedBackend)
  end

  def get(key)
    @backend.get(key)
  end

  def set(key, value, ttl:)
    @backend.set(key, value, ttl: ttl)
  end
end
