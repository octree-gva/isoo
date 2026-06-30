# frozen_string_literal: true

class RequestMetrics
  OPERATIONAL_PREFIXES = ['/health', '/metrics'].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, headers, body = @app.call(env)
    record(env, status, start) unless operational?(env['PATH_INFO'])
    [status, headers, body]
  end

  private

  def operational?(path)
    OPERATIONAL_PREFIXES.any? { |prefix| path == prefix || path.start_with?("#{prefix}/") }
  end

  def record(_env, status, start)
    duration = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    MetricsRegistry.record_request(status: status, duration_seconds: duration)
  end
end
