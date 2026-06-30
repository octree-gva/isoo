# frozen_string_literal: true

module Presence
  class MemoryBackend
    def initialize
      @data = {}
      @mutex = Mutex.new
    end

    def get(key)
      @mutex.synchronize do
        entry = @data[key]
        return {} unless entry
        return {} if entry[:expires_at] < Time.now

        entry[:value]
      end
    end

    def set(key, value, ttl:)
      @mutex.synchronize do
        @data[key] = { value: value, expires_at: Time.now + ttl }
      end
    end
  end
end
