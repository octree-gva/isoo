# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe OidcDiscovery do
  let(:cache) { Cache::MemoryStore.new(namespace: 'test') }
  let(:discovery) do
    {
      'authorization_endpoint' => 'http://localhost:8080/oauth/v2/authorize',
      'token_endpoint' => 'http://localhost:8080/oauth/v2/token',
      'userinfo_endpoint' => 'http://localhost:8080/oidc/v1/userinfo'
    }
  end

  before do
    allow(Container).to receive(:cache).and_return(cache)
    ENV['OIDC_ISSUER'] = 'http://localhost:8080'
    ENV['OIDC_ISSUER_INTERNAL'] = 'http://zitadel:8080'
  end

  after { described_class.reset! }

  it 'caches discovery documents when cache is enabled' do
    calls = 0
    allow(described_class).to receive(:fetch_discovery_uncached).and_wrap_original do |_method, *_args|
      calls += 1
      discovery
    end

    described_class.endpoints
    described_class.reset!
    described_class.endpoints
    expect(calls).to eq(1)
  end

  it 'does not use cache when disabled' do
    allow(Container).to receive(:cache).and_return(Cache::NullStore.new)
    calls = 0
    allow(described_class).to receive(:fetch_discovery_uncached).and_wrap_original do |_method, *_args|
      calls += 1
      discovery
    end

    described_class.endpoints
    described_class.reset!
    described_class.endpoints
    expect(calls).to eq(2)
  end
end
