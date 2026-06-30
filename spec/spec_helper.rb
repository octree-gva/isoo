# frozen_string_literal: true

require 'fileutils'

# Match docker-compose / local Puma defaults so template cache and error pages behave like runtime.
ENV['RACK_ENV'] ||= 'development'

spec_data = File.expand_path('tmp/data', __dir__)
FileUtils.mkdir_p(File.join(spec_data, 'projects'))
source_templates = File.expand_path('../data/templates', __dir__)
target_templates = File.join(spec_data, 'templates')
FileUtils.rm_rf(target_templates)
FileUtils.ln_s(source_templates, target_templates)
ENV['DATA_PATH'] = spec_data

require 'simplecov'
SimpleCov.start do
  add_filter '/spec/'
  minimum_coverage 90
end

require 'rack/test'
require 'rack/builder'
require 'rack/session'
require 'rack/show_exceptions'
require_relative 'support/page_assertions'
require_relative 'support/project_helpers'

ENV['ENCRYPTION_SECRET'] ||= 'test-encryption-secret-for-specs-only-32b'
ENV['AUTH_DISABLED'] ||= '1'
require_relative '../app/app'

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  config.include Rack::Test::Methods
  config.include PageAssertions, type: :request
  config.include ProjectHelpers, type: :request

  config.define_derived_metadata(file_path: %r{/spec/system/}) do |metadata|
    metadata[:type] = :request
  end

  config.before do
    Container.reset!
    OidcDiscovery.reset!
    ENV.delete('MEMCACHE_SERVER')
    ENV.delete('MEMCACHE_NAMESPACE')
    @test_app = nil
  end

  def app
    @app ||= Rack::Builder.new do
      use Rack::Session::Cookie, secret: 'dev-secret-change-me' * 4, same_site: :lax, httponly: true
      use Rack::ShowExceptions if ENV.fetch('RACK_ENV', 'development') != 'production'
      run App.freeze.app
    end
  end
end
