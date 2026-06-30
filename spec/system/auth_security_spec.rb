# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/middleware/oidc_auth'

RSpec.describe 'authentication security', type: :request do
  def app
    @app ||= Rack::Builder.new do
      use Rack::Session::Cookie, secret: 'dev-secret-change-me' * 4, same_site: :lax, httponly: true
      use OidcAuth
      run App.freeze.app
    end
  end

  around do |example|
    old_disabled = ENV.fetch('AUTH_DISABLED', nil)
    old_client = ENV.fetch('OIDC_CLIENT_ID', nil)
    old_redirect = ENV.fetch('OIDC_REDIRECT_URI', nil)
    ENV.delete('AUTH_DISABLED')
    ENV['OIDC_CLIENT_ID'] = 'test-client'
    ENV['OIDC_REDIRECT_URI'] = 'http://localhost:9292/auth/callback'
    example.run
  ensure
    ENV['AUTH_DISABLED'] = old_disabled
    ENV['OIDC_CLIENT_ID'] = old_client
    ENV['OIDC_REDIRECT_URI'] = old_redirect
  end

  it 'requires authentication for project pages' do
    get '/projects'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to eq('/auth/login')
  end

  it 'requires authentication for exports' do
    get '/projects/demo/export', { format: 'html' }
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to eq('/auth/login')
  end

  it 'requires authentication for annex downloads' do
    get '/projects/demo/annexes/1'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to eq('/auth/login')
  end

  it 'requires authentication for static assets' do
    get '/css/app.css'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to eq('/auth/login')
  end

  it 'allows health and metrics without authentication' do
    get '/health/live'
    expect(last_response.status).to eq(200)

    get '/metrics'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('isoo_up')
  end
end
