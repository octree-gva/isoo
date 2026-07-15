# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../support/demo_smoke_helpers'

RSpec.describe 'project export', type: :request do
  include DemoSmokeHelpers
  include ProjectHelpers

  let(:slug) { "export-test-#{SecureRandom.hex(3)}" }

  before do
    post '/projects', name: 'Export Test', slug: slug
  end

  it 'shows the export modal on the project dashboard' do
    expect_get_page!("/projects/#{slug}", 'project dashboard',
                     include_markers: ['id="export_modal"', 'name="format"', 'value="pdf"',
                                       'name="scope"', 'value="full"', 'value="data_protection"',
                                       'class="btn btn-ghost btn-sm navbar-export"'])
  end

  it 'downloads markdown export' do
    get "/projects/#{slug}/export", { format: 'md' }
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Type']).to include('text/markdown')
    expect(last_response.headers['Content-Disposition']).to include('export-test-v0.0.0.md')
    expect(last_response.body).to include('Export Test v0.0.0 export')
  end

  it 'includes bumped project version in export filename and title' do
    2.times do
      post "/projects/#{slug}/docs/organisation-overview",
           owner_params.merge(
             about_us: "About #{SecureRandom.hex(2)}",
             document_changes: 'minor edit',
             significant_change: '0'
           )
    end

    get "/projects/#{slug}/export", { format: 'html' }
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Disposition']).to include('export-test-v0.0.2.html')
    expect(last_response.body).to include('<h1>Export Test v0.0.2</h1>')
  end

  it 'includes owner footer on exported documents when owner is set' do
    post "/projects/#{slug}/docs/organisation-overview",
         owner_params.merge(
           about_us: 'Owned content',
           document_changes: 'set owner',
           significant_change: '0'
         )
    expect(last_response.status).to eq(302)

    get "/projects/#{slug}/docs/organisation-overview/export", { format: 'html' }
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('export-doc-owner')
    expect(last_response.body).to include('Test Owner')
    expect(last_response.body).to include('owner@example.com')
  end

  it 'downloads print-ready html' do
    get "/projects/#{slug}/export", { format: 'html' }
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Type']).to include('text/html')
    expect(last_response.headers['Content-Disposition']).to include('export-test-v0.0.0.html')
    expect(last_response.body.length).to be > 500
    expect(last_response.body).to include(
      '<!DOCTYPE html>',
      'data-export="isoo-html-v3"',
      '<style>',
      '--export-text:',
      'export-print-header',
      'export-cover',
      'export-main',
      'Table of contents'
    )
    expect(last_response.body).to match(%r{export-doc|</article>})
    expect(last_response.body).to include('export-print-header__logo')
    expect(last_response.body).not_to include('class="export-cover-note"', 'Public documents only')
  end

  it 'downloads pdf export generated from html' do
    pdf_bytes = +'%PDF-1.4 test'
    allow(ExportPdfRenderer).to receive(:render).and_return(pdf_bytes)

    get "/projects/#{slug}/export", { format: 'pdf' }

    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Type']).to include('application/pdf')
    expect(last_response.headers['Content-Disposition']).to include('export-test-v0.0.0.pdf')
    expect(last_response.body).to start_with('%PDF-1.4')
    expect(ExportPdfRenderer).to have_received(:render) do |html, display_url:, title:, export_date:, **|
      expect(html).to include('data-export="isoo-html-v3"', 'class="export-pdf"')
      expect(html).not_to include('<div class="export-print-header"')
      expect(display_url).to include("/projects/#{slug}/export?format=html")
      expect(title).to be_present
      expect(export_date).to match(/\A\d{4}-\d{2}-\d{2}\z/)
    end
  end

  it 'downloads populated html for a seeded project' do
    demo_slug = create_seeded_demo!
    get "/projects/#{demo_slug}/export", { format: 'html' }
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Cache-Control']).to include('no-store')
    expect(last_response.body).to include('data-export="isoo-html-v3"')
    expect(last_response.body.length).to be > 5000
    expect(last_response.body.scan('class="export-doc"').size).to be >= 80
    expect(last_response.body).to include('class="export-cover"', 'class="export-main"')
    expect(last_response.body).to match(/export-section-divider|export-version-control/)
    expect(last_response.body).not_to include(
      'class="export-cover-note"',
      'This file contains',
      'Public documents only',
      '&lt;h2&gt;'
    )
  end

  it 'filters html export by scope' do
    demo_slug = create_seeded_demo!
    manifest = ProjectManifest.load(File.join(App::DATA_PATH, 'projects', demo_slug))
    get "/projects/#{demo_slug}/export", { format: 'html' }
    full_count = last_response.body.scan('class="export-doc"').size

    get "/projects/#{demo_slug}/export", { format: 'html', scope: 'basic' }
    expect(last_response.status).to eq(200)
    expect(last_response.headers['Content-Disposition']).to include("#{manifest.export_basename}-basic.html")
    basic_count = last_response.body.scan('class="export-doc"').size

    expect(basic_count).to be < full_count
    expect(basic_count).to be >= 1
  end

  it 'redirects legacy export.md to markdown export' do
    get "/projects/#{slug}/export.md"
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to include("/projects/#{slug}/export?format=md")
    expect(last_response.headers['Location']).not_to include('scope=')
  end
end
