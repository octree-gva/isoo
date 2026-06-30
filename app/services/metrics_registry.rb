# frozen_string_literal: true

class MetricsRegistry
  @mutex = Mutex.new
  @started_at = Time.now
  @http_requests_total = 0
  @http_errors_total = 0
  @http_duration_sum = 0.0
  @http_duration_count = 0

  class << self
    def record_request(status:, duration_seconds:)
      @mutex.synchronize do
        @http_requests_total += 1
        @http_errors_total += 1 if status.to_i >= 500
        @http_duration_sum += duration_seconds
        @http_duration_count += 1
      end
    end

    def to_prometheus
      snapshot = snapshot_metrics
      project_count = safe_project_count
      format_metrics(snapshot, project_count)
    end

    def reset!
      @mutex.synchronize do
        @started_at = Time.now
        @http_requests_total = 0
        @http_errors_total = 0
        @http_duration_sum = 0.0
        @http_duration_count = 0
      end
    end

    private

    def snapshot_metrics
      @mutex.synchronize do
        {
          started_at: @started_at,
          http_requests_total: @http_requests_total,
          http_errors_total: @http_errors_total,
          http_duration_sum: @http_duration_sum,
          http_duration_count: @http_duration_count
        }
      end
    end

    def format_metrics(snapshot, project_count)
      duration_sum = format('%.6f', snapshot[:http_duration_sum])
      <<~PROM
        # HELP isoo_up ISOO process is running.
        # TYPE isoo_up gauge
        isoo_up 1
        # HELP isoo_started_at_seconds Unix time when the process started collecting metrics.
        # TYPE isoo_started_at_seconds gauge
        isoo_started_at_seconds #{snapshot[:started_at].to_i}
        # HELP isoo_http_requests_total Total HTTP requests (excluding health and metrics).
        # TYPE isoo_http_requests_total counter
        isoo_http_requests_total #{snapshot[:http_requests_total]}
        # HELP isoo_http_errors_total HTTP responses with status 5xx.
        # TYPE isoo_http_errors_total counter
        isoo_http_errors_total #{snapshot[:http_errors_total]}
        # HELP isoo_http_request_duration_seconds_sum Sum of HTTP request durations in seconds.
        # TYPE isoo_http_request_duration_seconds_sum counter
        isoo_http_request_duration_seconds_sum #{duration_sum}
        # HELP isoo_http_request_duration_seconds_count HTTP requests included in the duration sum.
        # TYPE isoo_http_request_duration_seconds_count counter
        isoo_http_request_duration_seconds_count #{snapshot[:http_duration_count]}
        # HELP isoo_projects_total Number of projects on disk.
        # TYPE isoo_projects_total gauge
        isoo_projects_total #{project_count}
      PROM
    end

    def safe_project_count
      ProjectCreator.new(data_root: App::DATA_PATH).list.size
    rescue StandardError
      -1
    end
  end
end
