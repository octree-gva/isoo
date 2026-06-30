# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/middleware/oidc_auth'

RSpec.describe OidcAuth do
  after { OidcDiscovery.reset! }

  it 'stores state in session on login redirect' do
    app = ->(_env) { [200, {}, ['ok']] }
    middleware = described_class.new(app)
    session = {}
    allow(OidcDiscovery).to receive(:endpoints).and_return(
      authorize: 'https://id.example.com/oauth/v2/authorize',
      token: 'https://id.example.com/oauth/v2/token',
      userinfo: 'https://id.example.com/oidc/v1/userinfo'
    )

    old_disabled = ENV.fetch('AUTH_DISABLED', nil)
    ENV.delete('AUTH_DISABLED')
    ENV['OIDC_CLIENT_ID'] = 'cid'
    ENV['OIDC_REDIRECT_URI'] = 'http://localhost:9292/auth/callback'

    status, headers, = middleware.call({ 'PATH_INFO' => '/auth/login', 'rack.session' => session })
    expect(status).to eq(302)
    expect(session['oidc_state']).to match(/\A[0-9a-f]{32}\z/)
    expect(headers['location']).to include('state=')
    expect(headers['location']).to include(session['oidc_state'])
  ensure
    ENV['AUTH_DISABLED'] = old_disabled
  end
end
