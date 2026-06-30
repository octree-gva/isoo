# frozen_string_literal: true

require 'fileutils'

module DataLayout
  REPO_ROOT = File.expand_path('..', __dir__)

  # Template bundles ship with the app repo (read-only blueprints).
  TEMPLATES_PATH = File.expand_path(
    ENV.fetch('TEMPLATES_PATH', File.join(REPO_ROOT, 'data', 'templates'))
  ).freeze

  # Project instances + nested git repo (gitignored in the app repo by default).
  DATA_PATH = File.expand_path(
    ENV.fetch('DATA_PATH', File.join(REPO_ROOT, 'tmp', 'data'))
  ).freeze

  NESTED_GITIGNORE = "/templates\n"

  module_function

  def ensure!
    FileUtils.mkdir_p(File.join(DATA_PATH, 'projects'))
    ensure_templates_link!
    ensure_nested_gitignore!
  end

  def ensure_templates_link!
    link = File.join(DATA_PATH, 'templates')
    target = TEMPLATES_PATH
    return if File.symlink?(link) && File.expand_path(File.readlink(link)) == target
    return if File.directory?(link) && !File.symlink?(link) && link == target

    FileUtils.rm_rf(link)
    FileUtils.ln_s(target, link)
  end

  def ensure_nested_gitignore!
    path = File.join(DATA_PATH, '.gitignore')
    return if File.file?(path)

    File.write(path, NESTED_GITIGNORE)
  end
end
