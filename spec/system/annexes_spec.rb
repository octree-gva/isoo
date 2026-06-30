# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'project annexes', type: :request do
  let(:slug) { create_test_project!(name: 'Annex Test') }

  it 'shows the annexes folder on a new project dashboard before any annex exists' do
    get "/projects/#{slug}"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include("/projects/#{slug}/annexes")
    expect(last_response.body).to include('Annexes')
    expect(last_response.body).not_to include('0 slots')
  end

  it 'shows an empty state on the annexes page before any annex exists' do
    expect_get_page!("/projects/#{slug}/annexes", 'empty annexes folder',
                     include_markers: ['annexes-heading', 'New annex', 'No annexes yet'])
  end

  context 'with seeded annexes' do
    before { seed_test_annexes!(slug) }

    it 'shows the annexes folder on the project dashboard' do
      get "/projects/#{slug}"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include("/projects/#{slug}/annexes")
      expect(last_response.body).to include('Annexes')
    end

    it 'lists annex slots on the annexes page' do
      get "/projects/#{slug}/annexes"
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Architectural schema').or include('architectural-schema')
      expect(last_response.body).to include('Network diagram').or include('network-diagram')
      expect(last_response.body).to include('image').or include('document')
    end

    it 'creates a new annex' do
      post "/projects/#{slug}/annexes"
      expect(last_response.status).to eq(302)
      follow_redirect!
      expect(last_response.status).to eq(200)
      expect(last_response.body).to include('Annex details')
      expect(last_response.body).to include('annex-upload-form')
    end
  end
end
