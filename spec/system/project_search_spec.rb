# frozen_string_literal: true

require_relative '../spec_helper'
require 'securerandom'

RSpec.describe 'project document search', type: :request do
  let(:slug) { "search-test-#{SecureRandom.hex(3)}" }

  before do
    post '/projects', name: 'Search Test', slug: slug
  end

  it 'finds a table row term and links to the licensing register' do
    post "/projects/#{slug}/docs/software-license-assets-register/rows",
         software_name: 'Squarespace',
         version: '7.1',
         paid_free: 'Paid',
         next_review_date: '2027-06-01'

    expect_get_page!("/projects/#{slug}?q=Squarespace", 'search results',
                     include_markers: [
                       'Software License Assets Register',
                       '/docs/software-license-assets-register',
                       'Squarespace'
                     ])
  end

  it 'shows an empty state when nothing matches' do
    expect_get_page!("/projects/#{slug}?q=zzznomatch999", 'empty search',
                     include_markers: ['No documents match your search.'])
  end
end
