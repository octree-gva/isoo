# frozen_string_literal: true

require 'json'
require 'dalli'

module Presence
  class MemcachedBackend
    def initialize(server:, namespace: 'isoo')
      @client = Dalli::Client.new(
        server,
        namespace: "#{namespace}:presence:",
        compress: true,
        socket_timeout: 1.5,
        socket_failure_delay: 0.2
      )
    end

    def get(key)
      raw = @client.get(key)
      return {} unless raw

      JSON.parse(raw)
    rescue JSON::ParserError, Dalli::DalliError
      {}
    end

    def set(key, value, ttl:)
      @client.set(key, JSON.generate(value), ttl)
    rescue Dalli::DalliError
      nil
    end
  end
end
