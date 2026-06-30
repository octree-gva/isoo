# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../support/demo_smoke_helpers'

RSpec.describe 'demo smoke', type: :request do
  include DemoSmokeHelpers

  let(:slug) { create_seeded_demo! }
  let(:manifest) { demo_manifest(slug) }

  it 'renders the project dashboard without a search query' do
    expect_get_page!("/projects/#{slug}", 'demo dashboard without search',
                     include_markers: ['id="project-search"', 'id="project-documents"', 'id="doc-label-'],
                     exclude_markers: ['id="search-results-heading"'])
  end

  it 'renders every page reachable from a seeded demo project' do
    aggregate_failures 'demo navigation' do
      expect_get_ok!("/projects/#{slug}", 'project dashboard')
      expect_get_ok!("/projects/#{slug}/reviews", 'reviews')
      expect_get_ok!("/projects/#{slug}/annexes", 'annexes index')

      openable_demo_documents(manifest).each do |doc|
        expect_get_ok!("/projects/#{slug}/docs/#{doc['doc_id']}", doc['doc_id'])
      end

      manifest.annexes.each do |annex|
        expect_get_ok!("/projects/#{slug}/docs/#{annex['doc_id']}", annex['doc_id'])
      end

      manifest.forms.each do |form|
        expect_get_ok!(
          "/projects/#{slug}/forms/#{form['doc_id']}",
          "form #{form['doc_id']}"
        )
        form.fetch('responses', []).each do |response|
          expect_get_ok!("/projects/#{slug}/docs/#{response['doc_id']}", response['doc_id'])
        end
      end
    end
  end

  it 'renders every table document with at least one row (edit wizard prefill path)' do
    table_docs = openable_demo_documents(manifest).select { |doc| doc['kind'] == 'table' }

    aggregate_failures 'populated tables' do
      table_docs.each do |doc|
        ensure_table_has_row!(slug, doc)
        path = "/projects/#{slug}/docs/#{doc['doc_id']}"
        expect_get_page!(path, doc['doc_id'], include_markers: ['data-wizard-prefill='])
      end
    end
  end
end
