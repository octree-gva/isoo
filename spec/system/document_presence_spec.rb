# frozen_string_literal: true

require_relative '../spec_helper'
require 'json'
require 'securerandom'

RSpec.describe 'document presence', type: :request do
  let(:slug) { "presence-#{SecureRandom.hex(3)}" }

  before do
    post '/projects', name: 'Presence Test', slug: slug
  end

  it 'reports no other editors on heartbeat' do
    post "/projects/#{slug}/docs/organisation-overview/presence"
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body['editors']).to eq([])
    expect(body['poll_interval']).to eq(5)
  end

  it 'shows another editor from a different session' do
    post "/projects/#{slug}/docs/organisation-overview/presence"

    other = Rack::MockSession.new(app, 'other-session')
    other.post "/projects/#{slug}/docs/organisation-overview/presence"

    post "/projects/#{slug}/docs/organisation-overview/presence"
    body = JSON.parse(last_response.body)
    expect(body['editors'].size).to eq(1)
    expect(body['editors'].first['name']).to eq('dev@local')
  end
end
