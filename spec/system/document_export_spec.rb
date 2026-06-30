# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'document export', type: :request do
  include ProjectHelpers

  let(:slug) { create_test_project!(name: 'Doc Export Test') }

  def doc_export_modal_markers(doc_id)
    [
      'id="document_export_modal"',
      'name="format"',
      'value="pdf"',
      %(action="/projects/#{slug}/docs/#{doc_id}/export"),
      'class="btn btn-ghost btn-sm navbar-export"'
    ]
  end

  it 'shows format-only export on a text document' do
    expect_get_page!("/projects/#{slug}/docs/organisation-overview", 'text document',
                     include_markers: doc_export_modal_markers('organisation-overview'),
                     exclude_markers: ['name="scope"', 'name="export_tags[]"'])
  end

  it 'shows format-only export on a table document' do
    expect_get_page!("/projects/#{slug}/docs/legal-and-contractual-requirements-register",
                     'table document',
                     include_markers: doc_export_modal_markers('legal-and-contractual-requirements-register'),
                     exclude_markers: ['name="scope"'])
  end

  it 'shows format-only export on annex asset detail' do
    seed_test_annexes!(slug)
    expect_get_page!("/projects/#{slug}/docs/architectural-schema", 'annex detail',
                     include_markers: doc_export_modal_markers('architectural-schema'),
                     exclude_markers: ['name="scope"'])
  end

  it 'shows format-only export on a form response' do
    form_id = 'audit-report-template'
    post "/projects/#{slug}/forms/#{form_id}/responses"
    response_id = "#{form_id}-1"

    expect_get_page!("/projects/#{slug}/docs/#{response_id}", 'form response',
                     include_markers: doc_export_modal_markers(response_id),
                     exclude_markers: ['name="scope"'])
  end

  it 'downloads markdown for a single document' do
    doc_id = 'organisation-overview'
    get "/projects/#{slug}/docs/#{doc_id}/export", { format: 'md' }
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Type']).to include('text/markdown')
    expect(last_response.headers['Content-Disposition']).to include("#{slug}-#{doc_id}.md")
    expect(last_response.body).to include('# Organisation Overview')
    expect(last_response.body.scan(/^# /).size).to eq(1)
  end

  it 'downloads print-ready html for a single document' do
    doc_id = 'organisation-overview'
    get "/projects/#{slug}/docs/#{doc_id}/export", { format: 'html' }
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Type']).to include('text/html')
    expect(last_response.headers['Content-Disposition']).to include("#{slug}-#{doc_id}.html")
    expect(last_response.body).to include('data-export="isoo-html-v3"', 'class="export-doc"')
    expect(last_response.body.scan('class="export-doc"').size).to eq(1)
  end

  it 'downloads pdf for a single document' do
    doc_id = 'organisation-overview'
    pdf_bytes = +'%PDF-1.4 test'
    allow(ExportPdfRenderer).to receive(:render).and_return(pdf_bytes)

    get "/projects/#{slug}/docs/#{doc_id}/export", { format: 'pdf' }

    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Type']).to include('application/pdf')
    expect(last_response.headers['Content-Disposition']).to include("#{slug}-#{doc_id}.pdf")
    expect(ExportPdfRenderer).to have_received(:render) do |html, display_url:, title:, export_date:, **|
      expect(html.scan('class="export-doc"').size).to eq(1)
      expect(display_url).to include("/projects/#{slug}/docs/#{doc_id}/export?format=html")
      expect(title).to be_present
      expect(export_date).to match(/\A\d{4}-\d{2}-\d{2}\z/)
    end
  end
end
