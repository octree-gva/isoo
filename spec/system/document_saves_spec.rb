# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'document saves', type: :request do
  let(:slug) { create_test_project!(name: 'Save Test') }

  before { seed_test_annexes!(slug) }

  it 'saves text with version bump' do
    post "/projects/#{slug}/docs/organisation-overview",
         about_us: 'Updated about',
         document_changes: 'about us',
         significant_change: '1'
    expect(last_response.status).to eq(302)

    get "/projects/#{slug}/docs/organisation-overview"
    expect(last_response.body).to include('Updated about')
  end

  it 'adds table row' do
    post "/projects/#{slug}/docs/legal-and-contractual-requirements-register/rows",
         standard: 'GDPR', requirement: 'Comply', applicability: 'All'
    expect(last_response.status).to eq(302)
  end

  it 'updates a table row via wizard patch' do
    post "/projects/#{slug}/docs/legal-and-contractual-requirements-register/rows",
         standard: 'GDPR', requirement: 'Comply', applicability: 'All'

    row_path = last_response.headers['Location']
    row_id = row_path.split('/').last

    post "/projects/#{slug}/docs/legal-and-contractual-requirements-register/rows",
         row_id: row_id, _method: 'patch', standard: 'ISO 27001', requirement: 'Updated', applicability: 'All'
    expect(last_response.status).to eq(302)

    get "/projects/#{slug}/docs/legal-and-contractual-requirements-register"
    expect(last_response.body).to include('ISO 27001')
  end

  it 'uploads annex file' do
    file = Rack::Test::UploadedFile.new(StringIO.new('png'), 'image/png', original_filename: 'diagram.png')
    post "/projects/#{slug}/docs/architectural-schema/annex",
         file: file, title: 'Architecture', document_changes: 'Initial upload'
    expect(last_response.status).to eq(302)
    get "/projects/#{slug}/annexes/1"
    expect(last_response.status).to eq(200)
  end
end
