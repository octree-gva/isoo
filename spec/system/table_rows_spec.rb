# frozen_string_literal: true

require_relative '../spec_helper'
require 'securerandom'

RSpec.describe 'table rows', type: :request do
  let(:slug) { "row-test-#{SecureRandom.hex(3)}" }
  let(:doc_id) { 'starter-leaver-mover-access-register' }

  before do
    post '/projects', name: 'Row Test', slug: slug
  end

  it 'shows a row at a unique URL as a read-only form' do
    post "/projects/#{slug}/docs/#{doc_id}/rows",
         reference: '1',
         request_type: 'Starter',
         request_date: '2026-03-01',
         employee_name: 'Alex Example',
         line_manager: 'Pat Manager',
         form_location_url: 'https://forms.example.com/slm',
         systems_requiring_access: 'GitHub, Slack',
         status: 'Submitted'

    expect(last_response.status).to eq(302)
    row_path = last_response.headers['Location']
    expect(row_path).to match(%r{/projects/#{slug}/docs/#{doc_id}/rows/[0-9a-f-]{36}\z})

    get row_path
    expect_rendered_page!(label: 'table row show', path: row_path,
                          include_markers: [
                            'Alex Example',
                            'GitHub, Slack',
                            'https://forms.example.com/slm',
                            'data-table-row-show',
                            'Back to table',
                            'data-wizard-open="edit_row_modal"'
                          ],
                          exclude_markers: ['id="new_row_modal"'])
  end

  it 'redirects new rows to the row show page' do
    post "/projects/#{slug}/docs/legal-and-contractual-requirements-register/rows",
         standard: 'GDPR', requirement: 'Test', applicability: 'All'

    expect(last_response.headers['Location']).to match(%r{/rows/[0-9a-f-]{36}\z})
  end

  it 'updates a row from the wizard and returns to the row show page' do
    post "/projects/#{slug}/docs/#{doc_id}/rows",
         reference: '2',
         request_type: 'Leaver',
         request_date: '2026-03-02',
         employee_name: 'Before Edit',
         line_manager: 'Manager',
         systems_requiring_access: 'Email',
         status: 'Draft'

    row_path = last_response.headers['Location']
    row_id = row_path.split('/').last

    post "/projects/#{slug}/docs/#{doc_id}/rows",
         row_id: row_id,
         _method: 'patch',
         reference: '2',
         request_type: 'Leaver',
         request_date: '2026-03-02',
         employee_name: 'After Edit',
         line_manager: 'Manager',
         systems_requiring_access: 'Email',
         status: 'Closed'

    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to eq(row_path)

    get row_path
    expect_rendered_page!(label: 'updated row show', path: row_path,
                          include_markers: ['After Edit', 'Closed'])
  end

  it 'links table rows to their show page' do
    post "/projects/#{slug}/docs/#{doc_id}/rows",
         reference: '3',
         request_type: 'Mover',
         request_date: '2026-03-03',
         employee_name: 'Linked Row',
         line_manager: 'Manager',
         systems_requiring_access: 'VPN',
         status: 'Submitted'

    row_path = last_response.headers['Location']

    get "/projects/#{slug}/docs/#{doc_id}"
    expect_rendered_page!(label: 'table index with row link', path: "/projects/#{slug}/docs/#{doc_id}",
                          include_markers: [row_path, 'View'])
  end
end
