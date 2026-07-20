# frozen_string_literal: true

require_relative '../data_layout'

module StorageBackend
  class PreconditionError < StandardError; end

  BACKENDS = %w[local git webdav s3].freeze
  PREFLIGHT_NAME = '.isoo-preflight'

  module_function

  def name
    raw = ENV.fetch('STORAGE_BACKEND', 'local').to_s.strip.downcase
    raw = 'local' if raw.empty?
    unless BACKENDS.include?(raw)
      raise PreconditionError,
            "Unknown STORAGE_BACKEND=#{raw.inspect} (expected #{BACKENDS.join(', ')})"
    end

    raw
  end

  def git?
    name == 'git'
  end

  def build(name: self.name, data_path: DataLayout::DATA_PATH)
    case name
    when 'local' then LocalStorageBackend.new(data_path: data_path)
    when 'git' then GitStorageBackend.new(data_path: data_path)
    when 'webdav' then WebdavStorageBackend.new(data_path: data_path)
    when 's3' then S3StorageBackend.new(data_path: data_path)
    else
      raise PreconditionError, "Unknown STORAGE_BACKEND=#{name.inspect}"
    end
  end

  def ensure_writable_data_path!(root)
    FileUtils.mkdir_p(File.join(root, 'projects'))
    probe = File.join(root, 'projects', PREFLIGHT_NAME)
    File.write(probe, 'ok')
    File.delete(probe)
  rescue StandardError => e
    raise PreconditionError, "DATA_PATH not writable (#{root}): #{e.message}"
  end

  def each_sync_file(root)
    root = File.expand_path(root)
    Dir.glob(File.join(root, '**', '*'), File::FNM_DOTMATCH).each do |abs|
      next unless File.file?(abs)

      rel = abs.delete_prefix("#{root}/")
      next if ['.', '..'].include?(rel)
      next if rel == '.git' || rel.start_with?('.git/')
      next if rel == 'templates' || rel.start_with?('templates/')

      yield rel, abs
    end
  end
end
