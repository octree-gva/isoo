# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/middleware/oidc_auth'

RSpec.describe 'MCP endpoint', type: :request do
  def mcp_app
    @mcp_app ||= Rack::Builder.new do
      use Rack::Session::Cookie, secret: 'dev-secret-change-me' * 4, same_site: :lax, httponly: true
      use OidcAuth
      run App.freeze.app
    end
  end

  def app
    mcp_app
  end

  def json_rpc(method, params: {}, id: 1)
    { 'jsonrpc' => '2.0', 'id' => id, 'method' => method, 'params' => params }
  end

  def post_mcp(slug, body, token: nil, headers: {})
    hdrs = { 'CONTENT_TYPE' => 'application/json' }.merge(headers)
    hdrs['HTTP_AUTHORIZATION'] = "Bearer #{token}" if token
    post "/projects/#{slug}/mcp", body.is_a?(String) ? body : JSON.generate(body), hdrs
  end

  def create_access!(slug, audience: 'full', mode: 'read')
    store = McpAccessStore.new(File.join(App::DATA_PATH, 'projects', slug))
    store.create!(name: 'Test MCP', audience: audience, mode: mode)
  end

  before do
    McpRateLimiter.reset!
  end

  it 'returns 401 without bearer token' do
    slug = create_test_project!
    post_mcp(slug, json_rpc('initialize'))
    expect(last_response.status).to eq(401)
  end

  it 'initializes and lists read tools for a read token' do
    slug = create_test_project!
    _access, token = create_access!(slug, mode: 'read')

    post_mcp(slug, json_rpc('initialize'), token: token)
    expect(last_response.status).to eq(200)
    result = JSON.parse(last_response.body)['result']
    expect(result['protocolVersion']).to eq(McpServer::PROTOCOL_VERSION)
    expect(result['capabilities']).to have_key('tools')

    post_mcp(slug, json_rpc('tools/list'), token: token,
                                           headers: { 'HTTP_MCP_PROTOCOL_VERSION' => McpServer::PROTOCOL_VERSION })
    names = JSON.parse(last_response.body).dig('result', 'tools').map { |t| t['name'] }
    expect(names).to include('list_documents', 'read_document')
    expect(names).not_to include('update_document', 'create_table_row')
  end

  it 'lists write tools for a read_write token and rejects write on read token' do
    slug = create_test_project!
    _read_access, read_token = create_access!(slug, mode: 'read')
    _rw_access, rw_token = create_access!(slug, mode: 'read_write')

    post_mcp(slug, json_rpc('tools/list'), token: rw_token,
                                           headers: { 'HTTP_MCP_PROTOCOL_VERSION' => McpServer::PROTOCOL_VERSION })
    names = JSON.parse(last_response.body).dig('result', 'tools').map { |t| t['name'] }
    expect(names).to include('update_document')

    post_mcp(
      slug,
      json_rpc('tools/call', params: {
                 'name' => 'update_document',
                 'arguments' => { 'doc_id' => 'x', 'fields' => {}, 'changes' => 'n' }
               }),
      token: read_token,
      headers: { 'HTTP_MCP_PROTOCOL_VERSION' => McpServer::PROTOCOL_VERSION }
    )
    expect(JSON.parse(last_response.body)['error']['message']).to match(/Write not permitted/i)
  end

  it 'scopes list_documents by audience and omits withheld docs' do
    slug = create_test_project!
    project_root = File.join(App::DATA_PATH, 'projects', slug)
    store = Container.classified_store(project_root, scope: "project:#{slug}")
    manifest = ProjectManifest.load(project_root)
    doc = manifest.documents.find { |d| (d['kind'] || 'text') == 'text' }
    expect(doc).not_to be_nil

    TextDocumentStore.new(store).set_withheld(doc['path'], withheld: true, author: 'spec')

    _access, token = create_access!(slug, audience: 'soi', mode: 'read')
    post_mcp(
      slug,
      json_rpc('tools/call', params: { 'name' => 'list_documents', 'arguments' => {} }),
      token: token,
      headers: { 'HTTP_MCP_PROTOCOL_VERSION' => McpServer::PROTOCOL_VERSION }
    )
    docs = JSON.parse(last_response.body).dig('result', 'structuredContent', 'documents') ||
           begin
             text = JSON.parse(last_response.body).dig('result', 'content', 0, 'text')
             JSON.parse(text)['documents']
           end
    expect(docs.map { |d| d['doc_id'] }).not_to include(doc['doc_id'])
    expect(docs).to all(satisfy do |d|
      DocumentExportTags.matches?(
        manifest.documents.find { |x| x['doc_id'] == d['doc_id'] },
        scope: 'soi',
        store: store,
        manifest: manifest
      )
    end)
  end

  it 'rejects invalid Origin' do
    slug = create_test_project!
    _access, token = create_access!(slug)
    post_mcp(slug, json_rpc('initialize'), token: token,
                                           headers: { 'HTTP_ORIGIN' => 'https://evil.example' })
    expect(last_response.status).to eq(403)
  end
end
