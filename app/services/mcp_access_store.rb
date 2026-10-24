# frozen_string_literal: true

require 'securerandom'
require 'openssl'
require 'json'
require 'time'

# Per-project MCP bearer accesses. Tokens are shown once; only HMAC hashes are stored.
class McpAccessStore
  FILE_NAME = 'mcp_accesses.json'
  DEFAULT_TTL_DAYS = 90
  MODES = %w[read read_write].freeze
  AUDIENCES = %w[full soi data_protection basic].freeze

  class Access
    attr_reader :id, :name, :audience, :mode, :token_hash, :created_at, :expires_at, :revoked_at

    def initialize(attrs)
      @id = attrs['id'].to_s
      @name = attrs['name'].to_s
      @audience = attrs['audience'].to_s
      @mode = attrs['mode'].to_s
      @token_hash = attrs['token_hash'].to_s
      @created_at = attrs['created_at'].to_s
      @expires_at = attrs['expires_at'].to_s
      @revoked_at = attrs['revoked_at']
    end

    def active?
      return false unless @revoked_at.nil? || @revoked_at.to_s.empty?

      Time.now.utc < Time.parse(@expires_at)
    rescue ArgumentError
      false
    end

    def read_write?
      @mode == 'read_write'
    end
  end

  def initialize(project_root)
    @project_root = project_root
    @path = File.join(project_root, FILE_NAME)
  end

  def list
    load_records.map { |r| Access.new(r) }
  end

  def active
    list.select(&:active?)
  end

  def find(access_id)
    list.find { |a| a.id == access_id.to_s }
  end

  # Opt-in when no file yet. Legacy files without an `enabled` key stay on.
  # Creating credentials sets `enabled: true` when the key was absent.
  def enabled?
    return false unless File.file?(@path)

    doc = load_document
    return true unless doc.key?('enabled')

    doc['enabled'] == true
  end

  def enabled=(value)
    doc = load_document
    doc['enabled'] = value ? true : false
    doc['accesses'] = Array(doc['accesses'])
    save_document(doc)
  end

  def create!(name:, audience:, mode:, expires_in_days: DEFAULT_TTL_DAYS) # rubocop:disable Metrics/MethodLength
    name = name.to_s.strip
    raise ArgumentError, 'name required' if name.empty?

    audience = audience.to_s
    mode = mode.to_s
    raise ArgumentError, 'invalid audience' unless AUDIENCES.include?(audience)
    raise ArgumentError, 'invalid mode' unless MODES.include?(mode)

    token = "isoo_mcp_#{SecureRandom.urlsafe_base64(32)}"
    now = Time.now.utc
    days = expires_in_days.to_i
    days = DEFAULT_TTL_DAYS if days <= 0
    record = {
      'id' => SecureRandom.uuid,
      'name' => name,
      'audience' => audience,
      'mode' => mode,
      'token_hash' => self.class.hash_token(token),
      'created_at' => now.iso8601,
      'expires_at' => (now + (days * 86_400)).iso8601,
      'revoked_at' => nil
    }
    records = load_records
    records << record
    save_records(records)
    [Access.new(record), token]
  end

  def revoke!(access_id)
    records = load_records
    found = false
    records.each do |r|
      next unless r['id'] == access_id.to_s

      r['revoked_at'] = Time.now.utc.iso8601
      found = true
    end
    raise ArgumentError, 'unknown access' unless found

    save_records(records)
  end

  def authenticate(bearer_token)
    return nil unless enabled?

    hash = self.class.hash_token(bearer_token.to_s)
    access = list.find { |a| a.token_hash == hash }
    return nil unless access&.active?

    access
  end

  def self.hash_token(token)
    OpenSSL::HMAC.hexdigest('SHA256', pepper, token.to_s)
  end

  def self.pepper
    ENV.fetch('ENCRYPTION_SECRET') do
      raise 'ENCRYPTION_SECRET required for MCP tokens'
    end
  end

  private

  def load_document
    return { 'accesses' => [] } unless File.file?(@path)

    data = JSON.parse(File.read(@path, encoding: 'UTF-8'))
    data = {} unless data.is_a?(Hash)
    data['accesses'] = Array(data['accesses'])
    data
  rescue JSON::ParserError
    { 'accesses' => [] }
  end

  def load_records
    load_document['accesses']
  end

  def save_records(records)
    doc = load_document
    doc['accesses'] = records
    doc['enabled'] = true unless doc.key?('enabled')
    save_document(doc)
  end

  def save_document(doc)
    File.write(@path, JSON.pretty_generate(doc))
  end
end
