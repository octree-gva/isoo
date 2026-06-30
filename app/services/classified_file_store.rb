# frozen_string_literal: true

require 'yaml'

class ClassifiedFileStore
  attr_reader :root

  def initialize(store)
    @store = store
    @root = store.root
  end

  def read(relative)
    enc = encrypted_path(relative)
    return DocumentCipher.decrypt(@store.read_binary(enc)) if @store.exist?(enc)

    @store.read(relative)
  end

  def write(relative, content, classification:, audit: {})
    if DocumentCipher.confidential?(classification)
      write_confidential(relative, content, audit)
    else
      write_plain(relative, content)
    end
  end

  def exist?(relative)
    @store.exist?(relative) || @store.exist?(encrypted_path(relative))
  end

  def audit(relative)
    path = audit_path(relative)
    return {} unless @store.exist?(path)

    YAML.safe_load(@store.read(path), permitted_classes: [Time, Date, DateTime, Symbol]) || {}
  end

  private

  def write_confidential(relative, content, audit)
    @store.write_binary(encrypted_path(relative), DocumentCipher.encrypt(content))
    @store.write(audit_path(relative), audit.merge(stored_encrypted: true).to_yaml)
    @store.delete(relative) if @store.exist?(relative)
  end

  def write_plain(relative, content)
    @store.write(relative, content)
    enc = encrypted_path(relative)
    @store.delete(enc) if @store.exist?(enc)
    audit = audit_path(relative)
    @store.delete(audit) if @store.exist?(audit)
  end

  def encrypted_path(relative)
    "#{relative}.enc"
  end

  def audit_path(relative)
    relative.sub(/\.[^.]+\z/, '.audit.yaml')
  end
end
