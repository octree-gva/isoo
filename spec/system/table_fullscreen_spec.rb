# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'table fullscreen', type: :request do
  let!(:slug) { create_test_project!(name: 'Fullscreen Test') }
  let(:doc_id) { 'legal-and-contractual-requirements-register' }

  it 'shows the fullscreen table editor' do
    get "/projects/#{slug}/docs/#{doc_id}/fullscreen"
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('table-fullscreen-header')
    expect(last_response.body).to include('fullscreen-table-form')
    expect(last_response.body).to include('table-fullscreen-footer')
    expect(last_response.body).to include('/js/markdown-editor.js')
    expect(last_response.body).to include('/js/form-draft.js')
    expect(last_response.body).to include('data-form-draft=')
    expect(last_response.body).to include('data-draft-baseline=')
    expect(last_response.body).to include('id="leave_modal"')
    expect(last_response.body).to include('window.I18n = ')
    expect(last_response.body).to include('New row')
    expect(last_response.body).not_to include('id="version-control-heading"')
    expect(last_response.body).not_to include('id="document-owner-name"')
    expect(last_response.body).not_to include('id="document-owner-heading"')
  end

  it 'shows document owner on the standard table page only' do
    get "/projects/#{slug}/docs/#{doc_id}"
    expect(last_response.body).to include('id="document-owner-name"')
    expect(last_response.body).to include('id="document-owner-email"')
  end

  it 'shows version control on the table details page only' do
    get "/projects/#{slug}/docs/#{doc_id}"
    expect(last_response.body).to include('Document Version Control')
  end

  it 'links from the table page to fullscreen' do
    get "/projects/#{slug}/docs/#{doc_id}"
    expect(last_response.body).to include("/projects/#{slug}/docs/#{doc_id}/fullscreen")
    expect(last_response.body).to include('Expand fullscreen')
  end

  it 'saves edited rows from fullscreen' do
    post "/projects/#{slug}/docs/#{doc_id}/rows", standard: 'GDPR', requirement: 'Comply', applicability: 'All',
                                                  return_to: 'fullscreen'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to include('/fullscreen')

    get "/projects/#{slug}/docs/#{doc_id}/fullscreen"
    row_id = last_response.body[/name="rows\[([^\]]+)\]\[standard\]"/, 1]
    expect(row_id).not_to be_nil

    post "/projects/#{slug}/docs/#{doc_id}/fullscreen",
         rows: { row_id => { 'standard' => 'ISO 27001', 'requirement' => 'Updated', 'applicability' => 'All' } },
         document_changes: 'fullscreen save'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to include('/fullscreen')

    get "/projects/#{slug}/docs/#{doc_id}/fullscreen"
    expect(last_response.body).to include('ISO 27001')
    expect(last_response.body).not_to include('id="version-control-heading"')

    get "/projects/#{slug}/docs/#{doc_id}"
    expect(last_response.body).to include('Document Version Control', 'fullscreen save')
  end
end
