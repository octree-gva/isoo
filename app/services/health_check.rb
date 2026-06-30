# frozen_string_literal: true

class HealthCheck
  def self.live
    { status: 'ok' }
  end

  def self.ready
    checks = {
      'data_path' => data_path_ok?,
      'templates' => templates_ok?
    }
    checks['memcached'] = memcached_ok? if memcached_configured?

    status = checks.values.all? ? 'ok' : 'degraded'
    { status: status, checks: checks }
  end

  class << self
    private

    def data_path_ok?
      path = App::DATA_PATH
      File.directory?(path) && File.writable?(path)
    end

    def templates_ok?
      File.file?(File.join(App::TEMPLATES_PATH, 'voca', 'manifest.yaml'))
    end

    def memcached_configured?
      !ENV.fetch('MEMCACHE_SERVER', '').strip.empty?
    end

    def memcached_ok?
      cache = Container.cache
      return true unless cache.enabled?

      cache.fetch('health:ping', scope: 'global', expires_in: 1) { 'pong' } == 'pong'
    rescue StandardError
      false
    end
  end
end
