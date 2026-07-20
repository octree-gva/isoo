# frozen_string_literal: true

require 'fileutils'

require_relative 'storage_backend'

class S3StorageBackend
  # rubocop:disable Metrics/ParameterLists -- mirrors env-backed S3 client options
  def initialize(data_path: DataLayout::DATA_PATH,
                 bucket: ENV.fetch('S3_BUCKET', ''),
                 prefix: ENV.fetch('S3_PREFIX', 'isoo-data'),
                 region: ENV.fetch('S3_REGION', 'us-east-1'),
                 endpoint: ENV.fetch('S3_ENDPOINT', ''),
                 access_key_id: ENV.fetch('S3_ACCESS_KEY_ID', ''),
                 secret_access_key: ENV.fetch('S3_SECRET_ACCESS_KEY', ''),
                 force_path_style: ENV.fetch('S3_FORCE_PATH_STYLE', '0') == '1')
    @data_path = File.expand_path(data_path)
    @bucket = bucket.to_s.strip
    @prefix = prefix.to_s.strip.gsub(%r{\A/+|/+\z}, '')
    @region = region.to_s.strip
    @endpoint = endpoint.to_s.strip
    @access_key_id = access_key_id.to_s
    @secret_access_key = secret_access_key.to_s
    @force_path_style = force_path_style
  end
  # rubocop:enable Metrics/ParameterLists

  def name
    's3'
  end

  # rubocop:disable Naming/PredicateMethod -- bang API returns success boolean
  def check!
    StorageBackend.ensure_writable_data_path!(@data_path)
    raise StorageBackend::PreconditionError, 'S3_BUCKET is required' if @bucket.empty?
    raise StorageBackend::PreconditionError, 'S3_ACCESS_KEY_ID is required' if @access_key_id.empty?
    raise StorageBackend::PreconditionError, 'S3_SECRET_ACCESS_KEY is required' if @secret_access_key.empty?

    client.head_bucket(bucket: @bucket)
    key = object_key(StorageBackend::PREFLIGHT_NAME)
    client.put_object(bucket: @bucket, key: key, body: 'ok')
    client.delete_object(bucket: @bucket, key: key)
    true
  rescue StorageBackend::PreconditionError
    raise
  rescue StandardError => e
    raise StorageBackend::PreconditionError, "s3 preflight failed: #{e.message}"
  end

  def flush!(_message = nil)
    StorageBackend.each_sync_file(@data_path) do |rel, abs|
      client.put_object(bucket: @bucket, key: object_key(rel), body: File.binread(abs))
    end
    true
  end
  # rubocop:enable Naming/PredicateMethod

  alias commit flush!

  def pull!
    prefix = object_key('')
    continuation = nil
    loop do
      list_opts = { bucket: @bucket, prefix: prefix }
      list_opts[:continuation_token] = continuation if continuation
      resp = client.list_objects_v2(**list_opts)
      (resp.contents || []).each do |obj|
        key = obj.key
        rel = key.delete_prefix(prefix)
        next if rel.empty? || rel == StorageBackend::PREFLIGHT_NAME

        body = client.get_object(bucket: @bucket, key: key).body.read
        dest = File.join(@data_path, rel)
        FileUtils.mkdir_p(File.dirname(dest))
        File.binwrite(dest, body)
      end
      break unless resp.is_truncated

      continuation = resp.next_continuation_token
    end
    { status: :ok }
  rescue StandardError => e
    { status: :error, message: e.message }
  end

  private

  def client
    @client ||= begin
      require 'aws-sdk-s3'
      opts = {
        region: @region,
        access_key_id: @access_key_id,
        secret_access_key: @secret_access_key,
        force_path_style: @force_path_style
      }
      opts[:endpoint] = @endpoint unless @endpoint.empty?
      Aws::S3::Client.new(opts)
    end
  end

  def object_key(rel)
    rel = rel.to_s.delete_prefix('/')
    @prefix.empty? ? rel : File.join(@prefix, rel)
  end
end
