# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'documents', type: :request do
  let(:slug) { create_test_project!(name: 'Doc Test') }

  it 'opens and saves a text document' do
    expect_get_page!("/projects/#{slug}/docs/organisation-overview", 'organisation overview',
                     include_markers: [
                       'Organisation Overview',
                       'data-markdown-editor',
                       'has-page-footer',
                       'class="page-footer',
                       'text_wizard_modal',
                       'data-wizard-title-base="Organisation Overview"',
                       'Run wizard',
                       'data-form-draft=',
                       'data-draft-baseline=',
                       'id="leave_modal"',
                       '/js/form-draft.js'
                     ])

    post "/projects/#{slug}/docs/organisation-overview",
         about_us: 'We are a test org',
         document_changes: 'filled about us',
         significant_change: '0'
    expect(last_response.status).to eq(302)
    follow_redirect!
    expect_rendered_page!(
      label: 'organisation overview after save',
      path: "/projects/#{slug}/docs/organisation-overview",
      include_markers: ['data-toast', 'Document saved.']
    )
  end

  it 'persists markdown formatting from text document fields' do
    markdown = "**bold** and *italic*\n\n- first\n- second"
    post "/projects/#{slug}/docs/organisation-overview",
         about_us: markdown,
         document_changes: 'markdown formatting test',
         significant_change: '0'
    expect(last_response.status).to eq(302)
    follow_redirect!
    expect_rendered_page!(label: 'organisation overview markdown',
                          path: "/projects/#{slug}/docs/organisation-overview",
                          include_markers: ['**bold**', '*italic*', '- first'])

    store = ClassifiedFileStore.new(FileStore.new(File.join(App::DATA_PATH, 'projects', slug)))
    data = TextDocumentStore.new(store).read('context/organisation-overview')
    expect(data[:fields]['about_us']).to include('**bold**', '*italic*', '- first')
  end

  it 'opens a table document' do
    expect_get_page!("/projects/#{slug}/docs/legal-and-contractual-requirements-register",
                     'empty legal register',
                     include_markers: [
                       'id="new_row_modal"',
                       'id="delete_row_modal"',
                       'id="save_table_modal"',
                       'has-page-footer',
                       'class="page-footer',
                       'id="table-legal-and-contractual-requirements-register-empty"',
                       'No rows yet',
                       'type="date"',
                       'data-date-shortcut="today"',
                       'data-review-date="true"',
                       'class="toggle toggle-success'
                     ],
                     exclude_markers: ['<tbody>'])
  end

  it 'opens a table with switch columns' do
    expect_get_page!("/projects/#{slug}/docs/0c-iso-27001-implementation-checklist",
                     'implementation checklist',
                     include_markers: ['data-switch-default='])
  end

  it 'renders edit wizard prefill on a populated table' do
    post "/projects/#{slug}/docs/legal-and-contractual-requirements-register/rows",
         standard: 'GDPR', requirement: 'Comply', applicability: 'All'

    expect(last_response.headers['Location']).to match(%r{/rows/})

    expect_get_page!("/projects/#{slug}/docs/legal-and-contractual-requirements-register",
                     'populated legal register',
                     include_markers: ['data-wizard-prefill='],
                     exclude_markers: ['json_attr(row)'])
  end

  it 'renders a populated ROPA register' do
    post "/projects/#{slug}/docs/data-asset-register-ropa/rows",
         document: '1',
         who_here_owns_it_information_owner: 'Product',
         what_is_it_description_of_the_information_held: 'Customer CRM data',
         why_do_we_have_it_data_asset_purpose_of_the_processing: 'Support'

    expect_get_page!("/projects/#{slug}/docs/data-asset-register-ropa", 'populated ROPA',
                     include_markers: ['Customer CRM data', 'data-wizard-prefill='])
  end
end
