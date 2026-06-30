# frozen_string_literal: true

require 'dalli'

module Cache
  class MemcachedStore
    def initialize(server:, namespace: 'isoo')
      @namespace = namespace
      @client = Dalli::Client.new(
        server,
        namespace: "#{namespace}:",
        compress: true,
        socket_timeout: 1.5,
        socket_failure_delay: 0.2
      )
    end

    def enabled?
      true
    end

    def fetch(key, scope: 'global', expires_in: 3600, &block)
      @client.fetch(storage_key(key, scope), expires_in, &block)
    rescue Dalli::DalliError
      block.call
    end

    def bump(scope)
      @client.incr(version_key(scope), 1, nil, 1)
    rescue Dalli::DalliError
      nil
    end

    def delete(key, scope: 'global')
      @client.delete(storage_key(key, scope))
    rescue Dalli::DalliError
      false
    end

    private

    def storage_key(key, scope)
      "scope:#{scope}:v#{version(scope)}:#{key}"
    end

    def version_key(scope)
      "ver:#{scope}"
    end

    def version(scope)
      @client.get(version_key(scope)).to_i
    rescue Dalli::DalliError
      0
    end
  end
end
