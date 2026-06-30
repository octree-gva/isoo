# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'application errors', type: :request do
  it 'renders a 404 page for unknown routes' do
    get '/does-not-exist'

    expect(last_response.status).to eq(404)
    expect(last_response.body).to include('404', 'Not found')
  end
end
