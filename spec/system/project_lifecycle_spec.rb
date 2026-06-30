# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'project lifecycle', type: :request do
  it 'creates and exports a project' do
    slug = "test-#{SecureRandom.hex(4)}"
    post '/projects', name: 'Test Co', slug: slug
    expect(last_response.status).to eq(302)

    get "/projects/#{slug}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Test Co').or include(slug)

    get "/projects/#{slug}/export", format: 'md'
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Type']).to include('text/markdown')
  end
end
