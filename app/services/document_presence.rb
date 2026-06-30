# frozen_string_literal: true

require 'time'

class DocumentPresence
  TTL = 20
  STALE_AFTER = 15
  POLL_INTERVAL = 5

  def initialize(store: Container.presence_store)
    @store = store
  end

  def heartbeat(slug:, doc_id:, editor_id:, name:)
    key = room_key(slug, doc_id)
    editors = @store.get(key)
    now = Time.now.utc.iso8601
    editors[editor_id] ||= {}
    editors[editor_id]['name'] = name.to_s
    editors[editor_id]['since'] ||= now
    editors[editor_id]['last_seen'] = now
    editors = prune(editors)
    @store.set(key, editors, ttl: TTL)
    editors
  end

  def leave(slug:, doc_id:, editor_id:)
    key = room_key(slug, doc_id)
    editors = @store.get(key)
    editors.delete(editor_id)
    editors = prune(editors)
    if editors.empty?
      @store.set(key, {}, ttl: 1)
    else
      @store.set(key, editors, ttl: TTL)
    end
    editors
  end

  def others(slug:, doc_id:, editor_id:)
    prune(@store.get(room_key(slug, doc_id))).reject { |id, _| id == editor_id }.map do |id, meta|
      meta.merge('id' => id)
    end
  end

  def backend
    @store.memcached? ? 'memcached' : 'memory'
  end

  private

  def room_key(slug, doc_id)
    "#{slug}:#{doc_id}"
  end

  def prune(editors)
    cutoff = Time.now.utc - STALE_AFTER
    editors.select do |_id, meta|
      seen = meta['last_seen']
      next false if seen.to_s.empty?

      Time.iso8601(seen) > cutoff
    rescue ArgumentError
      false
    end
  end
end
