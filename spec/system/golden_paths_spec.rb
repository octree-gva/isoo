# frozen_string_literal: true

require_relative '../spec_helper'
require 'securerandom'

RSpec.describe 'golden paths', type: :request do
  include ProjectHelpers

  def create_project!(name: 'Golden Path Co', slug: nil)
    slug ||= "golden-#{SecureRandom.hex(3)}"
    post '/projects', name: name, slug: slug
    expect(last_response.status).to eq(302)
    slug
  end

  it 'creates a new project from the voca template' do
    slug = create_project!

    expect_get_page!("/projects/#{slug}", 'project dashboard',
                     include_markers: [
                       'Golden Path Co', 'organisation-overview', 'Annexes',
                       'badge badge-outline', 'ri-table-line'
                     ],
                     exclude_markers: ['(text)', '(table)', '(form,', '(annex,', 'ri-table-2-line'])

    manifest = ProjectManifest.load(File.join(App::DATA_PATH, 'projects', slug))
    expect(manifest.documents).not_to be_empty
    expect(manifest.forms).not_to be_empty
    expect(manifest.annexes.size).to eq(0)
  end

  it 'edits a text document and saves' do
    slug = create_project!

    expect_get_page!("/projects/#{slug}/docs/organisation-overview", 'organisation overview',
                     include_markers: ['has-page-footer'])

    post "/projects/#{slug}/docs/organisation-overview",
         owner_params.merge(
           about_us: 'Golden path: we ship secure open source.',
           document_changes: 'Filled about us for golden path test',
           significant_change: '0'
         )
    expect(last_response.status).to eq(302)
    follow_redirect_and_expect_page!('organisation overview after save',
                                     include_markers: ['Golden path: we ship secure open source.'])

    store = ClassifiedFileStore.new(FileStore.new(File.join(App::DATA_PATH, 'projects', slug)))
    data = TextDocumentStore.new(store).read('context/organisation-overview')
    expect(data[:fields]['about_us']).to include('Golden path')
  end

  it 'adds a table row and saves the table document' do
    slug = create_project!

    post "/projects/#{slug}/docs/legal-and-contractual-requirements-register/rows",
         standard: 'GDPR',
         requirement: 'Lawful processing',
         applicability: 'EU customer data',
         required: '1',
         last_assessed_date: '2026-01-15',
         next_assessment_date: '2027-06-01'
    expect(last_response.status).to eq(302)

    expect_get_page!("/projects/#{slug}/docs/legal-and-contractual-requirements-register",
                     'legal register with row',
                     include_markers: ['GDPR', 'data-wizard-prefill='])

    post "/projects/#{slug}/docs/legal-and-contractual-requirements-register",
         owner_params.merge(
           document_changes: 'Added GDPR row for golden path test',
           significant_change: '0'
         )
    expect(last_response.status).to eq(302)

    store = ClassifiedFileStore.new(FileStore.new(File.join(App::DATA_PATH, 'projects', slug)))
    table = TableDocumentStore.new(store).read('context/legal-and-contractual-requirements-register')
    expect(table[:rows].length).to eq(1)
    expect(table[:rows].first['standard']).to eq('GDPR')
    expect(table[:meta].dig('iso27001', 'version')).to eq('0.2.0')
  end

  it 'creates a form response and saves it' do
    slug = create_project!
    form_id = 'audit-report-template'

    expect_get_page!("/projects/#{slug}/forms/#{form_id}", 'audit form folder',
                     include_markers: ['New response'])

    post "/projects/#{slug}/forms/#{form_id}/responses"
    expect(last_response.status).to eq(302)

    response_id = "#{form_id}-1"
    manifest = ProjectManifest.load(File.join(App::DATA_PATH, 'projects', slug))
    expect(manifest.find_response(response_id)).not_to be_nil

    expect_get_page!("/projects/#{slug}/docs/#{response_id}", 'audit form response')

    post "/projects/#{slug}/docs/#{response_id}",
         owner_params.merge(
           key_findings_summary: 'Golden path audit: no critical findings.',
           document_changes: 'Recorded initial audit summary',
           significant_change: '0'
         )
    expect(last_response.status).to eq(302)

    expect_get_page!("/projects/#{slug}/docs/#{response_id}", 'saved audit form response',
                     include_markers: ['Golden path audit'])

    store = ClassifiedFileStore.new(FileStore.new(File.join(App::DATA_PATH, 'projects', slug)))
    _form, response = manifest.find_response(response_id)
    data = TextDocumentStore.new(store).read(response['path'])
    expect(data[:fields]['key_findings_summary']).to include('Golden path audit')
  end
end
