# frozen_string_literal: true

require 'json'
require 'time'

class McpAuditLog
  FILE_NAME = 'mcp_audit.jsonl'

  def initialize(project_root)
    @path = File.join(project_root, FILE_NAME)
  end

  def append(access_id:, tool:, doc_id: nil)
    line = JSON.generate(
      'at' => Time.now.utc.iso8601,
      'access_id' => access_id.to_s,
      'tool' => tool.to_s,
      'doc_id' => doc_id&.to_s
    )
    File.open(@path, 'a') { |f| f.puts(line) }
  end
end
