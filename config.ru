# frozen_string_literal: true

require_relative 'app/app'
require 'rack/session'
require_relative 'app/middleware/request_metrics'
require_relative 'app/middleware/oidc_auth'

use Rack::Session::Cookie, secret: ENV.fetch('SESSION_SECRET', 'dev-secret-change-me' * 4)
use RequestMetrics
use OidcAuth

run App.freeze.app
