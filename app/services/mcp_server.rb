# frozen_string_literal: true

require 'json'
require 'yaml'

# JSON-RPC MCP tools for a single project, scoped by McpAccessStore::Access.
class McpServer # rubocop:disable Metrics/ClassLength
  PROTOCOL_VERSION = '2025-11-25'
  MAX_BODY_BYTES = 1_048_576

  class Error < StandardError
    attr_reader :code, :data

    def initialize(message, code: -32_000, data: nil)
      super(message)
      @code = code
      @data = data
    end
  end

  READ_TOOLS = %w[
    list_documents read_document list_table_rows list_forms read_form
    list_form_answers read_form_answer
  ].freeze

  WRITE_TOOLS = %w[
    update_document create_table_row update_table_row delete_table_row
    create_form_answer update_form_answer
  ].freeze

  def initialize(project_root:, store:, manifest:, access:, slug:, git: nil)
    @root = project_root
    @store = store
    @manifest = manifest
    @access = access
    @slug = slug
    @git = git
    @audit = McpAuditLog.new(project_root)
  end

  def handle(method, params)
    case method.to_s
    when 'initialize'
      initialize_result
    when 'notifications/initialized', 'notifications/cancelled'
      nil
    when 'ping'
      {}
    when 'tools/list'
      { 'tools' => tool_definitions }
    when 'tools/call'
      call_tool(params)
    else
      raise Error.new("Method not found: #{method}", code: -32_601)
    end
  end

  private

  def initialize_result
    {
      'protocolVersion' => PROTOCOL_VERSION,
      'capabilities' => { 'tools' => {} },
      'serverInfo' => { 'name' => 'isoo', 'version' => '1.0.0' }
    }
  end

  def tool_definitions
    names = READ_TOOLS.dup
    names.concat(WRITE_TOOLS) if @access.read_write?
    names.map { |name| tool_schema(name) }
  end

  def tool_schema(name)
    {
      'name' => name,
      'description' => tool_description(name),
      'inputSchema' => input_schema(name)
    }
  end

  def tool_description(name)
    {
      'list_documents' => 'List text and table documents visible to this access.',
      'read_document' => 'Read a text document by doc_id.',
      'list_table_rows' => 'List active rows of a table document.',
      'list_forms' => 'List forms visible to this access.',
      'read_form' => 'Read form metadata by form doc_id.',
      'list_form_answers' => 'List answers for a form.',
      'read_form_answer' => 'Read one form answer by doc_id.',
      'update_document' => 'Update editable text document sections by schema keys.',
      'create_table_row' => 'Create a table row.',
      'update_table_row' => 'Update a table row by row_id.',
      'delete_table_row' => 'Soft-delete a table row by row_id.',
      'create_form_answer' => 'Create a new form answer from the form template.',
      'update_form_answer' => 'Update a form answer text document sections.'
    }.fetch(name)
  end

  def input_schema(name) # rubocop:disable Metrics/MethodLength
    base = { 'type' => 'object', 'additionalProperties' => false }
    case name
    when 'list_documents', 'list_forms'
      base.merge('properties' => {}, 'required' => [])
    when 'read_document', 'list_table_rows', 'read_form', 'list_form_answers', 'create_form_answer'
      base.merge(
        'properties' => { 'doc_id' => { 'type' => 'string', 'minLength' => 1 } },
        'required' => ['doc_id']
      )
    when 'read_form_answer'
      base.merge(
        'properties' => {
          'doc_id' => { 'type' => 'string', 'minLength' => 1 },
          'fields' => { 'type' => 'object', 'additionalProperties' => { 'type' => 'string' } }
        },
        'required' => ['doc_id']
      )
    when 'update_form_answer'
      base.merge(
        'properties' => {
          'doc_id' => { 'type' => 'string', 'minLength' => 1 },
          'fields' => { 'type' => 'object', 'additionalProperties' => { 'type' => 'string' } }
        },
        'required' => %w[doc_id fields]
      )
    when 'update_document'
      base.merge(
        'properties' => {
          'doc_id' => { 'type' => 'string', 'minLength' => 1 },
          'fields' => { 'type' => 'object', 'additionalProperties' => { 'type' => 'string' } },
          'changes' => { 'type' => 'string', 'minLength' => 1 }
        },
        'required' => %w[doc_id fields changes]
      )
    when 'create_table_row'
      base.merge(
        'properties' => {
          'doc_id' => { 'type' => 'string', 'minLength' => 1 },
          'attrs' => { 'type' => 'object', 'additionalProperties' => { 'type' => 'string' } }
        },
        'required' => %w[doc_id attrs]
      )
    when 'update_table_row'
      base.merge(
        'properties' => {
          'doc_id' => { 'type' => 'string', 'minLength' => 1 },
          'row_id' => { 'type' => 'string', 'minLength' => 1 },
          'attrs' => { 'type' => 'object', 'additionalProperties' => { 'type' => 'string' } }
        },
        'required' => %w[doc_id row_id attrs]
      )
    when 'delete_table_row'
      base.merge(
        'properties' => {
          'doc_id' => { 'type' => 'string', 'minLength' => 1 },
          'row_id' => { 'type' => 'string', 'minLength' => 1 }
        },
        'required' => %w[doc_id row_id]
      )
    else
      raise Error.new("Unknown tool schema: #{name}", code: -32_602)
    end
  end

  def call_tool(params)
    name = params['name'].to_s
    args = params['arguments'].is_a?(Hash) ? params['arguments'] : {}
    raise Error.new('Unknown tool', code: -32_602) unless known_tool?(name)
    raise Error.new('Write not permitted', code: -32_000) if WRITE_TOOLS.include?(name) && !@access.read_write?

    validate_args!(name, args)
    result = dispatch_tool(name, args)
    @audit.append(access_id: @access.id, tool: name, doc_id: args['doc_id'])
    tool_result(result)
  end

  def known_tool?(name)
    READ_TOOLS.include?(name) || WRITE_TOOLS.include?(name)
  end

  def validate_args!(name, args)
    schema = input_schema(name)
    required = Array(schema['required'])
    required.each do |key|
      val = args[key]
      if %w[fields attrs].include?(key)
        raise Error.new("Missing argument: #{key}", code: -32_602) unless val.is_a?(Hash)
      elsif val.nil? || val.to_s.empty?
        raise Error.new("Missing argument: #{key}", code: -32_602)
      end
    end
    allowed = schema.fetch('properties', {}).keys
    args.each_key do |key|
      raise Error.new("Unexpected argument: #{key}", code: -32_602) unless allowed.include?(key.to_s)
    end
  end

  def dispatch_tool(name, args) # rubocop:disable Metrics/CyclomaticComplexity
    case name
    when 'list_documents' then list_documents
    when 'read_document' then read_document(args['doc_id'])
    when 'list_table_rows' then list_table_rows(args['doc_id'])
    when 'list_forms' then list_forms
    when 'read_form' then read_form(args['doc_id'])
    when 'list_form_answers' then list_form_answers(args['doc_id'])
    when 'read_form_answer' then read_form_answer(args['doc_id'])
    when 'update_document' then update_document(args)
    when 'create_table_row' then create_table_row(args)
    when 'update_table_row' then update_table_row(args)
    when 'delete_table_row' then delete_table_row(args)
    when 'create_form_answer' then create_form_answer(args)
    when 'update_form_answer' then update_form_answer(args)
    else
      raise Error.new('Unknown tool', code: -32_602)
    end
  end

  def tool_result(payload)
    {
      'content' => [{ 'type' => 'text', 'text' => JSON.generate(payload) }],
      'structuredContent' => payload,
      'isError' => false
    }
  end

  def visible_docs
    @manifest.documents.reject { |doc| excluded?(doc) }
  end

  def visible_forms
    @manifest.forms.reject { |form| excluded?(form) }
  end

  def excluded?(doc)
    return true if DocumentWithhold.document_withheld?(doc, store: @store, manifest: @manifest)
    return false if @access.audience == 'full'

    !DocumentExportTags.matches?(doc, scope: @access.audience, store: @store, manifest: @manifest)
  end

  def require_visible!(doc)
    raise Error.new('Document not found', code: -32_000) if doc.nil? || excluded?(doc)

    doc
  end

  def list_documents
    {
      'documents' => visible_docs.map do |doc|
        {
          'doc_id' => doc['doc_id'],
          'title' => doc['title'] || doc['doc_id'],
          'kind' => doc['kind'] || 'text'
        }
      end
    }
  end

  def read_document(doc_id)
    doc = require_visible!(@manifest.documents.find { |d| d['doc_id'] == doc_id })
    raise Error.new('Not a text document', code: -32_000) unless (doc['kind'] || 'text') == 'text'

    data = TextDocumentStore.new(@store).read(doc['path'])
    {
      'doc_id' => doc_id,
      'title' => doc['title'] || data[:meta]['title'],
      'fields' => data[:fields],
      'version' => data[:meta].dig('iso27001', 'version')
    }
  end

  def list_table_rows(doc_id)
    doc = require_visible!(@manifest.documents.find { |d| d['doc_id'] == doc_id })
    raise Error.new('Not a table document', code: -32_000) unless doc['kind'] == 'table'

    data = TableDocumentStore.new(@store).read(doc['path'])
    {
      'doc_id' => doc_id,
      'rows' => data[:rows].map { |row| row.reject { |k, _| k.to_s.start_with?('_') && k != '_row_id' } }
    }
  end

  def list_forms
    {
      'forms' => visible_forms.map do |form|
        {
          'doc_id' => form['doc_id'],
          'title' => form['title'] || form['doc_id'],
          'response_count' => form.fetch('responses', []).size
        }
      end
    }
  end

  def read_form(doc_id)
    form = require_visible!(@manifest.find_form(doc_id))
    {
      'doc_id' => form['doc_id'],
      'title' => form['title'] || form['doc_id'],
      'description' => FormDescription.resolve(form, store: @store, data_root: File.dirname(@root, 2)),
      'response_count' => form.fetch('responses', []).size
    }
  end

  def list_form_answers(form_id)
    form = require_visible!(@manifest.find_form(form_id))
    answers = form.fetch('responses', []).reject do |response|
      DocumentWithhold.document_withheld?(
        response.merge('form_id' => form_id, 'kind' => form['response_kind']),
        store: @store,
        manifest: @manifest
      )
    end
    {
      'form_id' => form_id,
      'answers' => answers.map { |r| { 'doc_id' => r['doc_id'], 'title' => r['title'] || r['doc_id'] } }
    }
  end

  def read_form_answer(doc_id)
    form, response = @manifest.find_response(doc_id)
    raise Error.new('Document not found', code: -32_000) unless form && response

    require_visible!(form)
    doc = response.merge('form_id' => form['doc_id'], 'kind' => form['response_kind'])
    raise Error.new('Document not found', code: -32_000) if DocumentWithhold.document_withheld?(doc, store: @store, manifest: @manifest)

    kind = form.fetch('response_kind', 'text')
    if kind == 'table'
      data = TableDocumentStore.new(@store).read(response['path'])
      { 'doc_id' => doc_id, 'form_id' => form['doc_id'], 'kind' => 'table', 'rows' => data[:rows] }
    else
      data = TextDocumentStore.new(@store).read(response['path'])
      { 'doc_id' => doc_id, 'form_id' => form['doc_id'], 'kind' => 'text', 'fields' => data[:fields],
        'title' => response['title'] }
    end
  end

  def update_document(args)
    doc = require_visible!(@manifest.documents.find { |d| d['doc_id'] == args['doc_id'] })
    raise Error.new('Not a text document', code: -32_000) unless (doc['kind'] || 'text') == 'text'

    store = TextDocumentStore.new(@store)
    data = store.read(doc['path'])
    fields = data[:fields].merge(stringify_hash(args['fields']))
    version = SemverBump.next_version(data[:meta].dig('iso27001', 'version'), significant: false)
    store.save(
      doc['path'],
      fields: fields,
      version: version,
      date: Time.now.utc.strftime('%Y-%m-%d'),
      author: @access.name,
      changes: args['changes'].to_s,
      withheld: nil
    )
    commit!("#{args['doc_id']} v#{version}: MCP update")
    { 'doc_id' => args['doc_id'], 'version' => version, 'ok' => true }
  end

  def create_table_row(args)
    doc = require_visible!(@manifest.documents.find { |d| d['doc_id'] == args['doc_id'] })
    raise Error.new('Not a table document', code: -32_000) unless doc['kind'] == 'table'

    row = TableDocumentStore.new(@store).add_row(doc['path'], stringify_hash(args['attrs']))
    commit!("#{args['doc_id']}: MCP create row")
    { 'doc_id' => args['doc_id'], 'row' => row, 'ok' => true }
  end

  def update_table_row(args)
    doc = require_visible!(@manifest.documents.find { |d| d['doc_id'] == args['doc_id'] })
    raise Error.new('Not a table document', code: -32_000) unless doc['kind'] == 'table'

    row = TableDocumentStore.new(@store).update_row(doc['path'], args['row_id'], stringify_hash(args['attrs']))
    raise Error.new('Row not found', code: -32_000) unless row

    commit!("#{args['doc_id']}: MCP update row")
    { 'doc_id' => args['doc_id'], 'row' => row, 'ok' => true }
  end

  def delete_table_row(args)
    doc = require_visible!(@manifest.documents.find { |d| d['doc_id'] == args['doc_id'] })
    raise Error.new('Not a table document', code: -32_000) unless doc['kind'] == 'table'

    TableDocumentStore.new(@store).soft_delete(doc['path'], args['row_id'])
    commit!("#{args['doc_id']}: MCP delete row")
    { 'doc_id' => args['doc_id'], 'row_id' => args['row_id'], 'ok' => true }
  end

  def create_form_answer(args)
    form = require_visible!(@manifest.find_form(args['doc_id']))
    template_id = @manifest.data['id'].to_s
    template_id = 'voca' if template_id.empty?
    data_root = File.dirname(@root, 2)
    doc_id = FormResponseCreator.new(
      data_root: data_root,
      template_id: template_id,
      git: nil
    ).create(project_slug: @slug, form_id: form['doc_id'], author: @access.name)
    @manifest = ProjectManifest.load(@root)
    commit!("#{form['doc_id']}: MCP create response #{doc_id}")
    { 'doc_id' => doc_id, 'form_id' => form['doc_id'], 'ok' => true }
  end

  def update_form_answer(args)
    form, response = @manifest.find_response(args['doc_id'])
    raise Error.new('Document not found', code: -32_000) unless form && response

    require_visible!(form)
    kind = form.fetch('response_kind', 'text')
    raise Error.new('Not a text form answer', code: -32_000) unless kind == 'text'

    doc = response.merge('form_id' => form['doc_id'], 'kind' => kind)
    raise Error.new('Document not found', code: -32_000) if DocumentWithhold.document_withheld?(doc, store: @store, manifest: @manifest)

    store = TextDocumentStore.new(@store)
    data = store.read(response['path'])
    fields = data[:fields].merge(stringify_hash(args['fields']))
    version = SemverBump.next_version(data[:meta].dig('iso27001', 'version'), significant: false)
    store.save(
      response['path'],
      fields: fields,
      version: version,
      date: Time.now.utc.strftime('%Y-%m-%d'),
      author: @access.name,
      changes: 'MCP update',
      withheld: nil
    )
    commit!("#{args['doc_id']} v#{version}: MCP update")
    { 'doc_id' => args['doc_id'], 'version' => version, 'ok' => true }
  end

  def stringify_hash(hash)
    (hash || {}).each_with_object({}) { |(k, v), acc| acc[k.to_s] = v.to_s }
  end

  def commit!(message)
    @manifest.bump_version!(significant: false)
    @git&.flush!(message)
  end
end
