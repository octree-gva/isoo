# frozen_string_literal: true

require 'json'

module RoutesObservability
  def routes_health(r)
    r.is('ready') { r.get { render_health(HealthCheck.ready) } }
    r.is('live') { r.get { render_health(HealthCheck.live) } }
    r.is { r.get { render_health(HealthCheck.live) } }
  end

  def render_health(body)
    ok = body[:status] == 'ok'
    response.status = ok ? 200 : 503
    response['Content-Type'] = 'application/json'
    JSON.generate(body)
  end

  def routes_metrics(_r)
    response['Content-Type'] = 'text/plain; version=0.0.4; charset=utf-8'
    MetricsRegistry.to_prometheus
  end
end
