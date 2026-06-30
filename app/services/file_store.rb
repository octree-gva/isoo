# frozen_string_literal: true

require 'pathname'

class FileStore
  attr_reader :root

  def initialize(root)
    @root = Pathname.new(root).expand_path
  end

  def absolute_path(relative)
    resolve(relative).to_s
  end

  def read(relative)
    resolve(relative).read(encoding: 'UTF-8')
  end

  def read_binary(relative)
    resolve(relative).binread
  end

  def write(relative, content)
    path = resolve(relative)
    path.parent.mkpath
    path.write(content, encoding: 'UTF-8')
  end

  def write_binary(relative, content)
    path = resolve(relative)
    path.parent.mkpath
    path.binwrite(content)
  end

  def delete(relative)
    path = resolve(relative)
    path.delete if path.exist?
  end

  def exist?(relative)
    resolve(relative).exist?
  end

  def join(*parts)
    parts.join('/')
  end

  private

  def resolve(relative)
    rel = relative.to_s.delete_prefix('/')
    path = (@root + rel).expand_path
    raise ArgumentError, 'path traversal' unless path.to_s.start_with?(@root.to_s)

    path
  end
end
