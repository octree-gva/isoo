# frozen_string_literal: true

# In-process per-token rate limiter for MCP tool calls.
class McpRateLimiter
  WINDOW_SECONDS = 60
  MAX_CALLS = 120

  def self.instance
    @instance ||= new
  end

  def self.reset!
    @instance = nil
  end

  def initialize
    @buckets = {}
    @mutex = Mutex.new
  end

  def allow?(token_id)
    @mutex.synchronize do
      now = Time.now.to_i
      bucket = (@buckets[token_id] ||= [])
      bucket.reject! { |t| t <= now - WINDOW_SECONDS }
      return false if bucket.size >= MAX_CALLS

      bucket << now
      true
    end
  end
end
