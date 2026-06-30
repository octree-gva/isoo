# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe MetricsRegistry do
  before { described_class.reset! }

  it 'records request counters' do
    described_class.record_request(status: 200, duration_seconds: 0.1)
    described_class.record_request(status: 500, duration_seconds: 0.2)

    output = described_class.to_prometheus
    expect(output).to include('isoo_http_requests_total 2')
    expect(output).to include('isoo_http_errors_total 1')
    expect(output).to include('isoo_http_request_duration_seconds_count 2')
  end
end
