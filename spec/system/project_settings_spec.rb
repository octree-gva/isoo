# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'project settings', type: :request do
  it 'shows general and MCP tabs' do
    slug = create_test_project!(name: 'Settings Co')
    expect_get_page!("/projects/#{slug}/settings", 'project settings general',
                     include_markers: [
                       'Project settings',
                       'settings-name',
                       'settings-description',
                       'tab=mcp'
                     ])

    expect_get_page!("/projects/#{slug}/settings?tab=mcp", 'project settings mcp',
                     include_markers: [
                       'settings-mcp-enabled',
                       'Credentials',
                       'mcp-name'
                     ])
  end

  it 'updates name and description' do
    slug = create_test_project!(name: 'Old Name')
    post "/projects/#{slug}/settings/general", name: 'New Name', description: 'A short brief'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to include('tab=general')

    manifest = ProjectManifest.load(File.join(App::DATA_PATH, 'projects', slug))
    expect(manifest.name).to eq('New Name')
    expect(manifest.description).to eq('A short brief')
  end

  it 'toggles MCP enabled' do
    slug = create_test_project!(name: 'MCP Toggle')
    store = McpAccessStore.new(File.join(App::DATA_PATH, 'projects', slug))
    _access, token = store.create!(name: 't', audience: 'full', mode: 'read')
    expect(store.authenticate(token)).not_to be_nil

    post "/projects/#{slug}/settings/mcp", enabled: '0'
    expect(last_response.status).to eq(302)
    expect(store.authenticate(token)).to be_nil

    post "/projects/#{slug}/settings/mcp", enabled: '1'
    expect(store.authenticate(token)).not_to be_nil
  end

  it 'creates credentials from the settings MCP tab' do
    slug = create_test_project!(name: 'MCP Create')
    post "/projects/#{slug}/settings/mcp/accesses",
         name: 'Open WebUI', audience: 'full', mode: 'read', expires_in_days: '30'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to include('tab=mcp')

    store = McpAccessStore.new(File.join(App::DATA_PATH, 'projects', slug))
    expect(store.list.map(&:name)).to include('Open WebUI')
    expect(store.enabled?).to be(true)
  end
end
