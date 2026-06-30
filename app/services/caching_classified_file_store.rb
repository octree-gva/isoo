# frozen_string_literal: true

class CachingClassifiedFileStore
  def initialize(store, cache:, scope:)
    @store = store
    @cache = cache
    @scope = scope
  end

  def read(relative)
    key = read_cache_key(relative)
    @cache.fetch(key, scope: @scope, expires_in: 3600) { @store.read(relative) }
  end

  def write(relative, content, classification:, audit: {})
    @store.write(relative, content, classification: classification, audit: audit)
    @cache.bump(@scope)
    content
  end

  def exist?(relative)
    @store.exist?(relative)
  end

  def audit(relative)
    @store.audit(relative)
  end

  private

  def read_cache_key(relative)
    path = physical_path(relative)
    "classified:#{relative}:#{CacheStore.file_fingerprint(path)}"
  end

  def physical_path(relative)
    enc = @store.root.join("#{relative}.enc")
    return enc.to_s if enc.exist?

    @store.root.join(relative).to_s
  end
end
