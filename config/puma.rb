# frozen_string_literal: true

threads_count = ENV.fetch('RACK_MAX_THREADS', 5).to_i
threads threads_count, threads_count

bind "tcp://#{ENV.fetch('BIND', '0.0.0.0')}:#{ENV.fetch('PORT', 9292)}"
environment ENV.fetch('RACK_ENV', 'production')

workers_count = ENV.fetch('WEB_CONCURRENCY', 0).to_i
workers workers_count if workers_count.positive?
preload_app! if workers_count.positive?

rackup File.expand_path('../config.ru', __dir__)
