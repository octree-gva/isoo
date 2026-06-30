# frozen_string_literal: true

module Cache
  class MemoryStore
    attr_reader :namespace

    def initialize(namespace: 'isoo')
      @namespace = namespace
      @entries = {}
      @versions = Hash.new(0)
    end

    def enabled?
      true
    end

    def fetch(key, scope: 'global', expires_in: nil, &block)
      full = storage_key(key, scope)
      return @entries[full][:value] if fresh_entry?(@entries[full], expires_in)

      value = block.call
      @entries[full] = { value: value, stored_at: Time.now }
      value
    end

    def bump(scope)
      @versions[scope] += 1
      prune_scope(scope)
      @versions[scope]
    end

    def delete(key, scope: 'global')
      @entries.delete(storage_key(key, scope))
    end

    def version(scope)
      @versions[scope]
    end

    private

    def storage_key(key, scope)
      "#{@namespace}:#{scope}:v#{@versions[scope]}:#{key}"
    end

    def fresh_entry?(entry, expires_in)
      return false unless entry

      return true unless expires_in

      Time.now - entry[:stored_at] < expires_in
    end

    def prune_scope(scope)
      prefix = "#{@namespace}:#{scope}:"
      @entries.delete_if { |key, _| key.start_with?(prefix) && !key.include?(":v#{@versions[scope]}:") }
    end
  end
end
