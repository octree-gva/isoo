# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'annex bbcode references', type: :request do
  include ProjectHelpers

  let(:slug) { create_test_project!(name: 'Annex BBCode Test') }
  let(:annex_doc_id) { 'architectural-schema' }

  before { seed_test_annexes!(slug) }

  it 'shows referenced-in on the asset detail page' do
    post "/projects/#{slug}/docs/organisation-overview",
         owner_params.merge(
           about_us: "Network layout: [ANNEX #{annex_doc_id}].",
           document_changes: 'Added annex reference',
           significant_change: '0'
         )
    expect(last_response.status).to eq(302)

    expect_get_page!("/projects/#{slug}/docs/#{annex_doc_id}", 'annex detail with references',
                     include_markers: [
                       'annex-referenced-in-heading',
                       'Organisation Overview',
                       'Text document'
                     ])
  end
end
