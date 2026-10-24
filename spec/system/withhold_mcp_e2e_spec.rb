# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../support/e2e_browser'
require_relative '../../app/middleware/oidc_auth'
require 'securerandom'
require 'json'

# E2E flows for withhold + MCP across documents, table rows, and form answers.
# Screenshots are written to ./tmp/e2e-screenshots/.
RSpec.describe 'withhold and MCP E2E', type: :request do
  include ProjectHelpers

  def project_store(slug)
    Container.classified_store(File.join(App::DATA_PATH, 'projects', slug), scope: "project:#{slug}")
  end

  def mcp_call(slug, token, method, params = {}, id: 1)
    header = {
      'CONTENT_TYPE' => 'application/json',
      'HTTP_AUTHORIZATION' => "Bearer #{token}",
      'HTTP_MCP_PROTOCOL_VERSION' => McpServer::PROTOCOL_VERSION
    }
    body = {
      'jsonrpc' => '2.0',
      'id' => id,
      'method' => method,
      'params' => params
    }
    post "/projects/#{slug}/mcp", JSON.generate(body), header
    expect(last_response.status).to eq(200), last_response.body[0, 500]
    JSON.parse(last_response.body)
  end

  def mcp_tool(slug, token, name, arguments = {})
    payload = mcp_call(slug, token, 'tools/call', { 'name' => name, 'arguments' => arguments })
    expect(payload['error']).to be_nil, payload.inspect
    structured = payload.dig('result', 'structuredContent')
    return structured if structured

    JSON.parse(payload.dig('result', 'content', 0, 'text'))
  end

  def mint_token!(slug, audience: 'full', mode: 'read_write')
    store = McpAccessStore.new(File.join(App::DATA_PATH, 'projects', slug))
    _access, token = store.create!(name: "e2e-#{audience}-#{mode}", audience: audience, mode: mode)
    token
  end

  def withhold_doc!(slug, doc_id, fields = {})
    post "/projects/#{slug}/docs/#{doc_id}",
         owner_params.merge(fields).merge(
           withheld: '1',
           document_changes: fields['document_changes'] || fields[:document_changes] || 'E2E withhold',
           significant_change: '0'
         )
    expect(last_response.status).to eq(302), last_response.body[0, 400]
  end

  before(:all) do # rubocop:disable RSpec/BeforeAfterAll
    E2eBrowser.start!(
      Rack::Builder.new do
        use Rack::Session::Cookie, secret: 'dev-secret-change-me' * 4, same_site: :lax, httponly: true
        use OidcAuth
        run App.freeze.app
      end
    )
  end

  after(:all) do # rubocop:disable RSpec/BeforeAfterAll
    E2eBrowser.stop!
  end

  before do
    McpRateLimiter.reset!
  end

  it 'withholds a text document from export and MCP, with UI screenshots' do
    slug = create_test_project!(name: 'E2E Doc Withhold')
    doc_id = 'organisation-overview'
    token = mint_token!(slug, mode: 'read')

    before_ids = mcp_tool(slug, token, 'list_documents')['documents'].map { |d| d['doc_id'] }
    expect(before_ids).to include(doc_id)

    E2eBrowser.visit("/projects/#{slug}/docs/#{doc_id}")
    expect(E2eBrowser.body).to include('Withhold from exports and MCP')
    E2eBrowser.screenshot!('01-document-before-withhold')

    withhold_doc!(slug, doc_id, 'about_us' => 'Visible content that must not export')

    E2eBrowser.visit("/projects/#{slug}/docs/#{doc_id}")
    expect(E2eBrowser.body).to match(/name="withheld"[^>]*checked|checked[^>]*name="withheld"/)
    expect(E2eBrowser.body).not_to include('document_export_modal')
    E2eBrowser.screenshot!('02-document-after-withhold')

    store = project_store(slug)
    meta = TextDocumentStore.new(store).read('context/organisation-overview')[:meta]
    expect(DocumentWithhold.from_meta(meta)).to be(true)

    exporter = ProjectExporter.new(File.join(App::DATA_PATH, 'projects', slug), store: store, slug: slug)
    expect(exporter.entry_for(doc_id)).to be_nil
    expect(exporter.export_markdown).not_to include('Visible content that must not export')

    after_ids = mcp_tool(slug, token, 'list_documents')['documents'].map { |d| d['doc_id'] }
    expect(after_ids).not_to include(doc_id)

    read = mcp_call(slug, token, 'tools/call',
                    { 'name' => 'read_document', 'arguments' => { 'doc_id' => doc_id } })
    expect(read['error']).not_to be_nil
  end

  it 'covers table rows: create, withhold table, export and MCP exclusion' do
    slug = create_test_project!(name: 'E2E Table Withhold')
    doc_id = 'legal-and-contractual-requirements-register'
    token = mint_token!(slug, mode: 'read_write')

    E2eBrowser.visit("/projects/#{slug}/docs/#{doc_id}")
    E2eBrowser.screenshot!('03-table-empty')

    created = mcp_tool(
      slug, token, 'create_table_row',
      'doc_id' => doc_id,
      'attrs' => {
        'standard' => 'GDPR',
        'requirement' => 'E2E lawful basis',
        'applicability' => 'EU data',
        'required' => '1',
        'last_assessed_date' => '2026-01-15',
        'next_assessment_date' => '2027-06-01'
      }
    )
    expect(created['ok']).to be(true)
    row_id = created.dig('row', '_row_id')
    expect(row_id).not_to be_nil

    rows = mcp_tool(slug, token, 'list_table_rows', 'doc_id' => doc_id)['rows']
    expect(rows.map { |r| r['standard'] }).to include('GDPR')

    E2eBrowser.visit("/projects/#{slug}/docs/#{doc_id}")
    expect(E2eBrowser.body).to include('GDPR')
    E2eBrowser.screenshot!('04-table-with-row')

    E2eBrowser.visit("/projects/#{slug}/docs/#{doc_id}/rows/#{row_id}")
    expect(E2eBrowser.body).to include('E2E lawful basis')
    E2eBrowser.screenshot!('05-table-row-show')

    withhold_doc!(slug, doc_id)

    E2eBrowser.visit("/projects/#{slug}/docs/#{doc_id}")
    expect(E2eBrowser.body).to match(/name="withheld"[^>]*checked|checked[^>]*name="withheld"/)
    E2eBrowser.screenshot!('06-table-withheld')

    store = project_store(slug)
    exporter = ProjectExporter.new(File.join(App::DATA_PATH, 'projects', slug), store: store, slug: slug)
    expect(exporter.entry_for(doc_id)).to be_nil

    listed = mcp_tool(slug, token, 'list_documents')['documents'].map { |d| d['doc_id'] }
    expect(listed).not_to include(doc_id)

    denied = mcp_call(slug, token, 'tools/call',
                      { 'name' => 'list_table_rows', 'arguments' => { 'doc_id' => doc_id } })
    expect(denied['error']).not_to be_nil
  end

  it 'covers form answers: create, edit via MCP, withhold answer and form cascade' do
    slug = create_test_project!(name: 'E2E Form Withhold')
    form_id = 'audit-report-template'
    token = mint_token!(slug, mode: 'read_write')

    E2eBrowser.visit("/projects/#{slug}/forms/#{form_id}")
    expect(E2eBrowser.body).to include('Withhold from exports and MCP')
    E2eBrowser.screenshot!('07-form-folder')

    created = mcp_tool(slug, token, 'create_form_answer', 'doc_id' => form_id)
    answer_id = created['doc_id']
    expect(answer_id).to eq("#{form_id}-1")

    E2eBrowser.visit("/projects/#{slug}/docs/#{answer_id}")
    E2eBrowser.screenshot!('08-form-answer-new')

    updated = mcp_tool(
      slug, token, 'update_form_answer',
      'doc_id' => answer_id,
      'fields' => {
        'key_findings_summary' => 'E2E form answer findings via MCP',
        'owner_name' => 'Test Owner',
        'owner_email' => 'owner@example.com'
      }
    )
    expect(updated['ok']).to be(true)

    E2eBrowser.visit("/projects/#{slug}/docs/#{answer_id}")
    expect(E2eBrowser.body).to include('E2E form answer findings via MCP')
    E2eBrowser.screenshot!('09-form-answer-updated')

    answers = mcp_tool(slug, token, 'list_form_answers', 'doc_id' => form_id)['answers']
    expect(answers.map { |a| a['doc_id'] }).to include(answer_id)

    withhold_doc!(
      slug, answer_id,
      'document_title' => 'Audit response 1',
      'key_findings_summary' => 'E2E form answer findings via MCP',
      'document_changes' => 'E2E withhold form answer'
    )

    E2eBrowser.visit("/projects/#{slug}/docs/#{answer_id}")
    expect(E2eBrowser.body).to match(/name="withheld"[^>]*checked|checked[^>]*name="withheld"/)
    E2eBrowser.screenshot!('10-form-answer-withheld')

    answers_after = mcp_tool(slug, token, 'list_form_answers', 'doc_id' => form_id)['answers']
    expect(answers_after.map { |a| a['doc_id'] }).not_to include(answer_id)

    store = project_store(slug)
    exporter = ProjectExporter.new(File.join(App::DATA_PATH, 'projects', slug), store: store,
                                                                               slug: slug, export_scope: 'full')
    expect(exporter.entry_for(answer_id)).to be_nil

    post "/projects/#{slug}/docs/#{answer_id}",
         owner_params.merge(
           document_title: 'Audit response 1',
           key_findings_summary: 'E2E form answer findings via MCP',
           document_changes: 'E2E clear answer withhold',
           significant_change: '0'
         )
    expect(last_response.status).to eq(302)

    post "/projects/#{slug}/forms/#{form_id}/withhold", withheld: '1'
    expect(last_response.status).to eq(302)

    E2eBrowser.visit("/projects/#{slug}/forms/#{form_id}")
    expect(E2eBrowser.body).to match(/name="withheld"[^>]*checked|checked[^>]*name="withheld"/)
    E2eBrowser.screenshot!('11-form-withheld')

    # Withheld form is invisible to MCP (cascade to answers via export + tools).
    forms = mcp_tool(slug, token, 'list_forms')['forms'].map { |f| f['doc_id'] }
    expect(forms).not_to include(form_id)
    cascade = mcp_call(slug, token, 'tools/call',
                       { 'name' => 'list_form_answers', 'arguments' => { 'doc_id' => form_id } })
    expect(cascade['error']).not_to be_nil

    exporter = ProjectExporter.new(File.join(App::DATA_PATH, 'projects', slug), store: store,
                                                                               slug: slug, export_scope: 'full')
    expect(exporter.entry_for(answer_id)).to be_nil
  end

  it 'rejects MCP writes for read tokens and accepts updates for read_write' do
    slug = create_test_project!(name: 'E2E MCP Modes')
    doc_id = 'organisation-overview'
    read_token = mint_token!(slug, mode: 'read')
    write_token = mint_token!(slug, mode: 'read_write')

    E2eBrowser.visit("/projects/#{slug}/settings?tab=mcp")
    expect(E2eBrowser.body).to include('Credentials')
    E2eBrowser.screenshot!('12-project-settings-mcp')

    denied = mcp_call(
      slug, read_token, 'tools/call',
      {
        'name' => 'update_document',
        'arguments' => {
          'doc_id' => doc_id,
          'fields' => {
            'about_us' => 'should fail',
            'owner_name' => 'Test Owner',
            'owner_email' => 'owner@example.com'
          },
          'changes' => 'nope'
        }
      }
    )
    expect(denied.dig('error', 'message')).to match(/Write not permitted/i)

    ok = mcp_tool(
      slug, write_token, 'update_document',
      'doc_id' => doc_id,
      'fields' => {
        'about_us' => 'E2E MCP write about us',
        'owner_name' => 'Test Owner',
        'owner_email' => 'owner@example.com'
      },
      'changes' => 'E2E MCP update'
    )
    expect(ok['ok']).to be(true)

    E2eBrowser.visit("/projects/#{slug}/docs/#{doc_id}")
    expect(E2eBrowser.body).to include('E2E MCP write about us')
    E2eBrowser.screenshot!('13-document-after-mcp-write')

    paths = Dir[File.join(E2eBrowser::SCREENSHOT_ROOT, '*.png')]
    expect(paths.size).to be >= 10
  end
end
