# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'health and metrics', type: :request do
  it 'returns live health without authentication' do
    get '/health/live'
    expect(last_response.status).to eq(200)
    expect(JSON.parse(last_response.body)).to eq('status' => 'ok')
  end

  it 'returns ready health without authentication' do
    get '/health/ready'
    expect(last_response.status).to eq(200)
    body = JSON.parse(last_response.body)
    expect(body['status']).to eq('ok')
    expect(body['checks']['data_path']).to be true
    expect(body['checks']['templates']).to be true
  end

  it 'exposes prometheus metrics without authentication' do
    get '/projects'
    get '/metrics'
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Type']).to include('text/plain')
    expect(last_response.body).to include('isoo_up 1')
    expect(last_response.body).to include('isoo_http_requests_total')
  end
end
