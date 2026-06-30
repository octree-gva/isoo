# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/middleware/oidc_auth'

RSpec.describe OidcAuth do
  after { OidcDiscovery.reset! }

  it 'passes through when auth disabled' do
    app = ->(_env) { [200, {}, ['ok']] }
    middleware = described_class.new(app)
    old_disabled = ENV.fetch('AUTH_DISABLED', nil)
    ENV['AUTH_DISABLED'] = '1'
    status, = middleware.call({ 'PATH_INFO' => '/projects' })
    expect(status).to eq(200)
  ensure
    if old_disabled
      ENV['AUTH_DISABLED'] = old_disabled
    else
      ENV.delete('AUTH_DISABLED')
    end
  end

  it 'redirects to login when auth enabled' do
    app = ->(_env) { [200, {}, ['ok']] }
    middleware = described_class.new(app)
    old_disabled = ENV.fetch('AUTH_DISABLED', nil)
    ENV.delete('AUTH_DISABLED')
    ENV['OIDC_CLIENT_ID'] = 'cid'
    ENV['OIDC_REDIRECT_URI'] = 'http://localhost/callback'
    status, headers, = middleware.call({ 'PATH_INFO' => '/projects', 'rack.session' => {} })
    expect(status).to eq(302)
    expect(headers['location']).to eq('/auth/login')
  ensure
    ENV['AUTH_DISABLED'] = old_disabled
  end

  it 'expires idle sessions server-side' do
    app = ->(_env) { [200, {}, ['ok']] }
    middleware = described_class.new(app)
    old_disabled = ENV.fetch('AUTH_DISABLED', nil)
    old_timeout = ENV.fetch('SESSION_IDLE_TIMEOUT_SECONDS', nil)
    ENV.delete('AUTH_DISABLED')
    ENV['OIDC_CLIENT_ID'] = 'cid'
    ENV['OIDC_REDIRECT_URI'] = 'http://localhost/callback'
    ENV['SESSION_IDLE_TIMEOUT_SECONDS'] = '120'
    session = {
      'user' => { 'email' => 'user@example.com' },
      'last_activity_at' => Time.now.to_i - 121
    }
    status, headers, = middleware.call({ 'PATH_INFO' => '/projects', 'rack.session' => session })
    expect(status).to eq(302)
    expect(headers['location']).to eq('/auth/login')
    expect(session).to be_empty
  ensure
    ENV['AUTH_DISABLED'] = old_disabled
    if old_timeout
      ENV['SESSION_IDLE_TIMEOUT_SECONDS'] = old_timeout
    else
      ENV.delete('SESSION_IDLE_TIMEOUT_SECONDS')
    end
  end

  it 'refreshes activity timestamp for authenticated requests' do
    app = ->(_env) { [200, {}, ['ok']] }
    middleware = described_class.new(app)
    old_disabled = ENV.fetch('AUTH_DISABLED', nil)
    ENV.delete('AUTH_DISABLED')
    ENV['OIDC_CLIENT_ID'] = 'cid'
    ENV['OIDC_REDIRECT_URI'] = 'http://localhost/callback'
    session = {
      'user' => { 'email' => 'user@example.com' },
      'last_activity_at' => Time.now.to_i - 10
    }
    status, = middleware.call({ 'PATH_INFO' => '/projects', 'rack.session' => session })
    expect(status).to eq(200)
    expect(session['last_activity_at']).to be >= Time.now.to_i - 1
  ensure
    ENV['AUTH_DISABLED'] = old_disabled
  end

  it 'blocks authenticated users from disallowed email domains' do
    app = ->(_env) { [200, {}, ['ok']] }
    middleware = described_class.new(app)
    old_disabled = ENV.fetch('AUTH_DISABLED', nil)
    old_domains = ENV.fetch('AUTH_ALLOWED_EMAIL_DOMAINS', nil)
    ENV.delete('AUTH_DISABLED')
    ENV['OIDC_CLIENT_ID'] = 'cid'
    ENV['OIDC_REDIRECT_URI'] = 'http://localhost/callback'
    ENV['AUTH_ALLOWED_EMAIL_DOMAINS'] = 'voca.city'
    session = {
      'user' => { 'email' => 'user@example.com' },
      'last_activity_at' => Time.now.to_i
    }
    status, headers, body = middleware.call({ 'PATH_INFO' => '/projects', 'rack.session' => session })
    expect(status).to eq(403)
    expect(headers['content-type']).to include('text/html')
    expect(body.join).to include('Forbidden', 'user@example.com')
    expect(session).to be_empty
  ensure
    ENV['AUTH_DISABLED'] = old_disabled
    if old_domains
      ENV['AUTH_ALLOWED_EMAIL_DOMAINS'] = old_domains
    else
      ENV.delete('AUTH_ALLOWED_EMAIL_DOMAINS')
    end
  end
end
