# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../support/demo_smoke_helpers'

RSpec.describe 'layout shell', type: :request do
  include DemoSmokeHelpers

  let(:slug) { create_seeded_demo! }

  it 'renders the app layout and client i18n on the project dashboard' do
    expect_get_page!("/projects/#{slug}", 'project dashboard',
                     include_markers: ['organisation-overview'])
  end

  it 'renders the starter-leaver-mover system access process document' do
    doc_id = 'starter-leaver-mover-system-access-process'
    expect_get_page!("/projects/#{slug}/docs/#{doc_id}", doc_id,
                     include_markers: ['has-page-footer', 'class="page-footer'])
  end
end
