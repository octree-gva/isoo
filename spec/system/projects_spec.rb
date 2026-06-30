# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'projects', type: :request do
  it 'lists projects' do
    expect_get_page!('/projects', 'projects index',
                     include_markers: [
                       'id="new_project_modal"',
                       'data-wizard-open="new_project_modal"',
                       'has-page-footer',
                       'class="page-footer'
                     ])
  end

  it 'shows the index when only one project exists' do
    allow(Container.projects).to receive(:list).and_return([{ slug: 'acme', name: 'Acme' }])
    expect_get_page!('/projects', 'projects index with one project',
                     include_markers: ['Acme', 'id="new_project_modal"'])
  end

  it 'redirects with an error when the slug already exists' do
    slug = create_test_project!(name: 'Existing Co')
    post '/projects', name: 'Another Co', slug: slug
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to end_with('/projects')
    follow_redirect!
    expect(last_response.body).to include('already exists')
  end
end
