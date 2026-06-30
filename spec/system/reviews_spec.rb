# frozen_string_literal: true

require_relative '../spec_helper'
require 'securerandom'

RSpec.describe 'project reviews', type: :request do
  let(:slug) { "review-test-#{SecureRandom.hex(3)}" }

  before do
    post '/projects', name: 'Review Test', slug: slug
  end

  it 'shows the reviews button on the project dashboard' do
    get "/projects/#{slug}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("/projects/#{slug}/reviews")
    expect(last_response.body).to include('Reviews')
  end

  it 'renders the reviews page' do
    get "/projects/#{slug}/reviews"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Reviews')
    expect(last_response.body).to include('5 oldest documents')
    expect(last_response.body).to include('Stale documents')
    expect(last_response.body).to include('Expired review dates')
  end
end
