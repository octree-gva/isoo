# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/services/oidc_discovery'

RSpec.describe OidcDiscovery do
  after { described_class.reset! }

  it 'rewrites token endpoint to internal issuer host' do
    stub_discovery = {
      'authorization_endpoint' => 'http://localhost:8080/oauth/v2/authorize',
      'token_endpoint' => 'http://localhost:8080/oauth/v2/token',
      'userinfo_endpoint' => 'http://localhost:8080/oidc/v1/userinfo'
    }
    allow(described_class).to receive(:fetch_discovery).and_return(stub_discovery)
    ENV['OIDC_ISSUER'] = 'http://localhost:8080'
    ENV['OIDC_ISSUER_INTERNAL'] = 'http://zitadel:8080'

    endpoints = described_class.endpoints
    expect(endpoints[:authorize]).to eq('http://localhost:8080/oauth/v2/authorize')
    expect(endpoints[:token]).to eq('http://zitadel:8080/oauth/v2/token')
    expect(endpoints[:userinfo]).to eq('http://zitadel:8080/oidc/v1/userinfo')
  end
end
