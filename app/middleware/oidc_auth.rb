# frozen_string_literal: true

require 'uri'
require 'securerandom'

require_relative '../session_idle'
require_relative '../services/oidc_discovery'
require_relative '../services/authorized_email_domains'
require_relative '../services/error_response'

class OidcAuth
  # Unauthenticated paths: OIDC flow, load-balancer probes, and Prometheus scraping only.
  # All project data, exports, annexes, and static assets require a valid session.
  OPERATIONAL_PREFIXES = ['/health'].freeze
  OPERATIONAL_EXACT = %w[/metrics].freeze
  AUTH_PATHS = %w[/auth/callback /auth/login /auth/logout].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    return @app.call(env) if ENV['AUTH_DISABLED'] == '1'
    return @app.call(env) if operational_path?(env['PATH_INFO'])

    session = env['rack.session'] ||= {}
    return handle_callback(env, session) if env['PATH_INFO'] == '/auth/callback'
    return redirect(login_url(session)) if env['PATH_INFO'] == '/auth/login'

    if env['PATH_INFO'] == '/auth/logout'
      session.clear
      return redirect('/')
    end

    return redirect('/auth/login') unless session['user']

    if SessionIdle.expired?(session)
      session.clear
      return redirect('/auth/login')
    end

    email = session.dig('user', 'email')
    unless AuthorizedEmailDomains.allowed?(email)
      session.clear
      return domain_forbidden_response(email)
    end

    SessionIdle.touch!(session)
    env['isoo.user'] = session['user']
    @app.call(env)
  rescue StandardError => e
    warn "[OidcAuth] #{e.class}: #{e.message}"
    ErrorResponse.rack(status: 500)
  end

  private

  def redirect(location)
    [302, { 'location' => location, 'content-type' => 'text/html' }, []]
  end

  def login_url(session)
    state = SecureRandom.hex(16)
    session['oidc_state'] = state
    params = {
      client_id: ENV.fetch('OIDC_CLIENT_ID'),
      response_type: 'code',
      scope: 'openid email profile',
      redirect_uri: ENV.fetch('OIDC_REDIRECT_URI'),
      state: state
    }
    "#{oidc_endpoints[:authorize]}?#{URI.encode_www_form(params)}"
  end

  def handle_callback(env, session)
    params = Rack::Utils.parse_query(env['QUERY_STRING'])
    unless params['code']
      return ErrorResponse.rack(
        status: 400,
        detail: IsooI18n.t('errors.details.missing_code')
      )
    end
    unless params['state'] == session.delete('oidc_state')
      return ErrorResponse.rack(
        status: 401,
        detail: IsooI18n.t('errors.details.invalid_state')
      )
    end

    token = exchange_code(params['code'])
    unless token['access_token']
      return ErrorResponse.rack(
        status: 502,
        detail: IsooI18n.t('errors.details.token_exchange_failed')
      )
    end

    userinfo = fetch_userinfo(token)
    email = userinfo['email'].to_s
    unless AuthorizedEmailDomains.allowed?(email)
      session.clear
      return domain_forbidden_response(email)
    end

    session['user'] = {
      'email' => email,
      'name' => userinfo['name'] || userinfo['preferred_username'] || email
    }
    SessionIdle.touch!(session)
    redirect('/projects')
  rescue StandardError => e
    warn "[OidcAuth callback] #{e.class}: #{e.message}"
    ErrorResponse.rack(status: 500)
  end

  def domain_forbidden_response(email)
    ErrorResponse.rack(
      status: 403,
      detail: IsooI18n.t('errors.details.email_domain_forbidden', email: email)
    )
  end

  def exchange_code(code)
    OidcDiscovery.post_form(
      oidc_endpoints[:token],
      grant_type: 'authorization_code',
      code: code,
      redirect_uri: ENV.fetch('OIDC_REDIRECT_URI'),
      client_id: ENV.fetch('OIDC_CLIENT_ID'),
      client_secret: ENV.fetch('OIDC_CLIENT_SECRET')
    )
  end

  def fetch_userinfo(token)
    OidcDiscovery.get_json(oidc_endpoints[:userinfo], 'Authorization' => "Bearer #{token['access_token']}")
  end

  def oidc_endpoints
    @oidc_endpoints ||= OidcDiscovery.endpoints
  end

  def operational_path?(path)
    OPERATIONAL_EXACT.include?(path) || OPERATIONAL_PREFIXES.any? { |prefix| path.start_with?(prefix) }
  end
end
