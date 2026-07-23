# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'export translation', type: :request do
  include ProjectHelpers

  let(:slug) { create_test_project!(name: 'Translate Export') }

  around do |example|
    original = ENV.fetch('DEEPL_API_KEY', nil)
    ENV.delete('DEEPL_API_KEY')
    example.run
  ensure
    if original.nil?
      ENV.delete('DEEPL_API_KEY')
    else
      ENV['DEEPL_API_KEY'] = original
    end
  end

  def lang_selector_markers
    ['name="lang"', 'value="fr"']
  end

  it 'hides the language selector without DEEPL_API_KEY' do
    expect_get_page!("/projects/#{slug}", 'project dashboard',
                     exclude_markers: lang_selector_markers)
    expect_get_page!("/projects/#{slug}/docs/organisation-overview", 'document page',
                     exclude_markers: lang_selector_markers)
  end

  it 'shows the language selector when DeepL is configured' do
    ENV['DEEPL_API_KEY'] = 'test-key'

    expect_get_page!("/projects/#{slug}", 'project dashboard with lang selector',
                     include_markers: lang_selector_markers)
    expect_get_page!("/projects/#{slug}/docs/organisation-overview", 'document page with lang selector',
                     include_markers: lang_selector_markers)
  end

  it 'ignores lang=fr without DEEPL_API_KEY' do
    get "/projects/#{slug}/docs/organisation-overview/export", { format: 'md', lang: 'fr' }
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('# Organisation Overview')
  end

  it 'translates export when lang=fr and DeepL is configured' do
    ENV['DEEPL_API_KEY'] = 'test-key'
    allow(DeepLTranslator).to receive(:translate) do |text, **|
      text.to_s.include?('Organisation Overview') ? 'Aperçu organisation' : 'Texte traduit'
    end

    get "/projects/#{slug}/docs/organisation-overview/export", { format: 'md', lang: 'fr' }

    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('# Aperçu organisation')
    expect(DeepLTranslator).to have_received(:translate).at_least(:once)
  end
end
