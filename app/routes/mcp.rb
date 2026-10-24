# frozen_string_literal: true

module RoutesMcp # rubocop:disable Metrics/ModuleLength
  def routes_mcp(r, slug)
    r.is do
      r.post { handle_mcp_post(r, slug) }
      r.get { handle_mcp_get(r, slug) }
    end
  end

  def handle_mcp_post(r, slug) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    origin = env['HTTP_ORIGIN'].to_s
    unless origin.empty?
      expected = mcp_expected_origin(r)
      unless origin == expected
        response.status = 403
        response['Content-Type'] = 'application/json'
        return JSON.generate(jsonrpc_error(nil, -32_000, 'Invalid Origin'))
      end
    end

    body = r.body.read
    if body.bytesize > McpServer::MAX_BODY_BYTES
      response.status = 413
      response['Content-Type'] = 'application/json'
      return JSON.generate(jsonrpc_error(nil, -32_000, 'Payload too large'))
    end

    access = authenticate_mcp_bearer
    unless access
      response.status = 401
      response['WWW-Authenticate'] = 'Bearer'
      response['Content-Type'] = 'application/json'
      return JSON.generate(jsonrpc_error(nil, -32_000, 'Unauthorized'))
    end

    unless mcp_rate_limiter.allow?(access.id)
      response.status = 429
      response['Content-Type'] = 'application/json'
      return JSON.generate(jsonrpc_error(nil, -32_000, 'Rate limit exceeded'))
    end

    payload = JSON.parse(body)
    messages = payload.is_a?(Array) ? payload : [payload]
    results = messages.map { |msg| process_mcp_message(msg, slug, access) }

    response['Content-Type'] = 'application/json'
    response['MCP-Protocol-Version'] = McpServer::PROTOCOL_VERSION
    JSON.generate(payload.is_a?(Array) ? results.compact : results.first)
  rescue JSON::ParserError
    response.status = 400
    response['Content-Type'] = 'application/json'
    JSON.generate(jsonrpc_error(nil, -32_700, 'Parse error'))
  end

  def handle_mcp_get(_r, _slug)
    access = authenticate_mcp_bearer
    unless access
      response.status = 401
      response['WWW-Authenticate'] = 'Bearer'
      return ''
    end

    # Stateless server: no SSE stream; clients use POST.
    response.status = 405
    response['Allow'] = 'POST'
    response['Content-Type'] = 'application/json'
    JSON.generate(jsonrpc_error(nil, -32_000, 'SSE not supported; use POST'))
  end

  def process_mcp_message(msg, slug, access) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    id = msg['id']
    method = msg['method'].to_s
    params = msg['params'].is_a?(Hash) ? msg['params'] : {}

    if method != 'initialize' && !method.start_with?('notifications/')
      version = env['HTTP_MCP_PROTOCOL_VERSION'].to_s
      if !version.empty? && version != McpServer::PROTOCOL_VERSION
        response.status = 400
        return jsonrpc_error(id, -32_000, "Unsupported MCP-Protocol-Version: #{version}")
      end
    end

    return nil if method.start_with?('notifications/') && id.nil?

    server = build_mcp_server(slug, access)
    result = server.handle(method, params)
    return nil if result.nil? && id.nil?

    { 'jsonrpc' => '2.0', 'id' => id, 'result' => result }
  rescue McpServer::Error => e
    jsonrpc_error(id, e.code, e.message, e.data)
  rescue ArgumentError, TableDocumentStore::ValidationError => e
    jsonrpc_error(id, -32_000, e.message)
  end

  def build_mcp_server(slug, access)
    project_root = File.join(App::DATA_PATH, 'projects', slug)
    McpServer.new(
      project_root: project_root,
      store: classified_store(slug),
      manifest: ProjectManifest.load(project_root),
      access: access,
      slug: slug,
      git: self.class.storage
    )
  end

  def authenticate_mcp_bearer
    header = env['HTTP_AUTHORIZATION'].to_s
    return nil unless header.match?(/\ABearer\s+\S+/i)

    token = header.sub(/\ABearer\s+/i, '').strip
    return nil if token.empty?

    McpAccessStore.new(File.join(App::DATA_PATH, 'projects', @slug)).authenticate(token)
  end

  def mcp_expected_origin(r)
    "#{r.scheme}://#{env['HTTP_HOST']}"
  end

  def mcp_rate_limiter
    self.class.mcp_rate_limiter
  end

  def jsonrpc_error(request_id, code, message, data = nil)
    err = { 'code' => code, 'message' => message }
    err['data'] = data if data
    { 'jsonrpc' => '2.0', 'id' => request_id, 'error' => err }
  end

  def create_mcp_access(r, slug)
    store = McpAccessStore.new(File.join(App::DATA_PATH, 'projects', slug))
    access, token = store.create!(
      name: r.params['name'],
      audience: r.params['audience'],
      mode: r.params['mode'],
      expires_in_days: r.params['expires_in_days']
    )
    self.class.storage.flush!("mcp: create access #{access.name}")
    rack_session['mcp_plain_token'] = token
    rack_session['mcp_plain_token_name'] = access.name
    flash_success('toast.mcp_access_created', name: access.name)
    r.redirect("/projects/#{slug}/settings?tab=mcp")
  rescue ArgumentError => e
    flash_error(e.message)
    r.redirect("/projects/#{slug}/settings?tab=mcp")
  end

  def revoke_mcp_access(r, slug, access_id)
    McpAccessStore.new(File.join(App::DATA_PATH, 'projects', slug)).revoke!(access_id)
    self.class.storage.flush!("mcp: revoke access #{access_id}")
    flash_success('toast.mcp_access_revoked')
    r.redirect("/projects/#{slug}/settings?tab=mcp")
  rescue ArgumentError => e
    flash_error(e.message)
    r.redirect("/projects/#{slug}/settings?tab=mcp")
  end
end
