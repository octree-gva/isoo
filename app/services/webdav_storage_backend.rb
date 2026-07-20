# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'base64'
require 'fileutils'

require_relative 'storage_backend'

class WebdavStorageBackend
  class Propfind < Net::HTTPRequest
    METHOD = 'PROPFIND'
    REQUEST_HAS_BODY = true
    RESPONSE_HAS_BODY = true
  end

  class Mkcol < Net::HTTPRequest
    METHOD = 'MKCOL'
    REQUEST_HAS_BODY = false
    RESPONSE_HAS_BODY = true
  end

  def initialize(data_path: DataLayout::DATA_PATH,
                 url: ENV.fetch('WEBDAV_URL', ''),
                 username: ENV.fetch('WEBDAV_USERNAME', ''),
                 password: ENV.fetch('WEBDAV_PASSWORD', ''))
    @data_path = File.expand_path(data_path)
    @base_url = url.to_s.strip.chomp('/')
    @username = username.to_s
    @password = password.to_s
  end

  def name
    'webdav'
  end

  # rubocop:disable Naming/PredicateMethod -- bang API returns success boolean
  def check!
    StorageBackend.ensure_writable_data_path!(@data_path)
    raise StorageBackend::PreconditionError, 'WEBDAV_URL is required' if @base_url.empty?

    propfind('/')
    probe = StorageBackend::PREFLIGHT_NAME
    put_object(probe, 'ok')
    delete_object(probe)
    true
  rescue StorageBackend::PreconditionError
    raise
  rescue StandardError => e
    raise StorageBackend::PreconditionError, "webdav preflight failed: #{e.message}"
  end

  def flush!(_message = nil)
    StorageBackend.each_sync_file(@data_path) do |rel, abs|
      put_object(rel, File.binread(abs))
    end
    true
  end
  # rubocop:enable Naming/PredicateMethod

  alias commit flush!

  def pull!
    list_files.each do |rel|
      next if rel.end_with?('/')

      body = get_object(rel)
      dest = File.join(@data_path, rel)
      FileUtils.mkdir_p(File.dirname(dest))
      File.binwrite(dest, body)
    end
    { status: :ok }
  rescue StandardError => e
    { status: :error, message: e.message }
  end

  private

  def uri_for(rel)
    path = rel.to_s.delete_prefix('/')
    URI.parse(path.empty? ? "#{@base_url}/" : "#{@base_url}/#{path}")
  end

  def http_request(req_class, rel, body: nil, headers: {})
    uri = uri_for(rel)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == 'https'
    req = req_class.new(uri)
    headers.each { |k, v| req[k] = v }
    req.body = body if body
    req.basic_auth(@username, @password) unless @username.empty?
    http.request(req)
  end

  def propfind(rel)
    res = http_request(
      Propfind, rel,
      body: '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>',
      headers: { 'Depth' => '1', 'Content-Type' => 'application/xml' }
    )
    raise "PROPFIND failed (#{res.code})" unless res.code.to_i.between?(200, 299) || res.code == '207'

    res
  end

  def put_object(rel, content)
    ensure_collections!(rel)
    res = http_request(Net::HTTP::Put, rel, body: content,
                                            headers: { 'Content-Type' => 'application/octet-stream' })
    raise "PUT #{rel} failed (#{res.code})" unless res.code.to_i.between?(200, 299)
  end

  def delete_object(rel)
    res = http_request(Net::HTTP::Delete, rel)
    raise "DELETE #{rel} failed (#{res.code})" unless res.code.to_i.between?(200, 299) || res.code == '404'
  end

  def get_object(rel)
    res = http_request(Net::HTTP::Get, rel)
    raise "GET #{rel} failed (#{res.code})" unless res.code.to_i.between?(200, 299)

    res.body
  end

  def ensure_collections!(rel)
    parts = File.dirname(rel).split('/').reject { |p| p.empty? || p == '.' }
    path = ''
    parts.each do |part|
      path = path.empty? ? part : "#{path}/#{part}"
      res = http_request(Mkcol, path)
      next if res.code.to_i.between?(200, 299) || %w[201 405 301].include?(res.code)

      raise "MKCOL #{path} failed (#{res.code})"
    end
  end

  def list_files
    res = http_request(
      Propfind, '/',
      body: '<?xml version="1.0"?><d:propfind xmlns:d="DAV:"><d:prop><d:resourcetype/></d:prop></d:propfind>',
      headers: { 'Depth' => 'infinity', 'Content-Type' => 'application/xml' }
    )
    raise "PROPFIND list failed (#{res.code})" unless res.code.to_i.between?(200, 299) || res.code == '207'

    hrefs = res.body.to_s.scan(%r{<[^>]*href[^>]*>([^<]+)</[^>]*href>}i).flatten
    base_path = URI.parse("#{@base_url}/").path
    hrefs.filter_map do |href|
      path = begin
        URI.parse(href).path
      rescue URI::InvalidURIError
        href
      end
      path = path.delete_prefix(base_path.to_s)
      path = path.delete_prefix('/')
      next if path.empty? || path == StorageBackend::PREFLIGHT_NAME
      next if path.end_with?('/')

      path
    end.uniq
  end
end
