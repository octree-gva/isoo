# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'routes', type: :request do
  let(:slug) { create_test_project!(name: 'Routes') }

  before { seed_test_annexes!(slug) }

  it 'redirects root to projects' do
    get '/'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to include('/projects')
  end

  it 'shows annex upload page' do
    expect_get_page!("/projects/#{slug}/docs/architectural-schema", 'annex upload',
                     include_markers: ['Upload'])
  end
end
