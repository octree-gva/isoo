# frozen_string_literal: true

require_relative '../data_layout'

class GitService
  class Error < StandardError; end

  def self.remote_sync_enabled?
    !ENV.fetch('GIT_REMOTE_URL', '').strip.empty?
  end

  def initialize(repo_path)
    @repo_path = File.expand_path(repo_path)
  end

  def ensure_repo!
    DataLayout.ensure_nested_gitignore!
    system('git', 'config', '--global', '--add', 'safe.directory', @repo_path)
    Dir.chdir(@repo_path) do
      system('git', 'init', '-b', 'main', out: File::NULL, err: File::NULL) unless File.directory?('.git')
      system('git', 'config', 'user.email', git_author_email)
      system('git', 'config', 'user.name', git_author_name)
    end
  end

  def commit(message)
    ensure_repo!
    Dir.chdir(@repo_path) do
      system('git', 'add', '-A', exception: true)
      status = `git status --porcelain`.strip
      return false if status.empty?

      system('git', 'commit', '-m', message, exception: true)
      push if push_enabled?
      true
    end
  end

  def pull
    return { status: :disabled } unless self.class.remote_sync_enabled?

    ensure_repo!
    Dir.chdir(@repo_path) do
      ensure_remote!
      return { status: :dirty } unless `git status --porcelain`.strip.empty?

      system('git', 'fetch', 'origin', exception: true)
      return { status: :ok, revision: current_revision, empty_remote: true } unless remote_branch_exists?('origin/main')

      system('git', 'reset', '--hard', 'origin/main', exception: true)
      { status: :ok, revision: current_revision }
    end
  rescue StandardError => e
    { status: :error, message: e.message }
  end

  private

  def push_enabled?
    ENV['GIT_FORCE_PUSH'] == '1' && self.class.remote_sync_enabled?
  end

  def push
    ensure_remote!
    system('git', 'push', '--force', 'origin', 'main', exception: true)
  end

  def ensure_remote!
    remote = ENV.fetch('GIT_REMOTE_URL').strip
    if `git remote`.include?('origin')
      system('git', 'remote', 'set-url', 'origin', remote, exception: true)
    else
      system('git', 'remote', 'add', 'origin', remote, exception: true)
    end
  end

  def remote_branch_exists?(ref)
    system('git', 'rev-parse', '--verify', ref, out: File::NULL, err: File::NULL)
  end

  def current_revision
    `git rev-parse --short HEAD`.strip
  end

  def git_author_email
    email = ENV['GIT_AUTHOR_EMAIL'].to_s.strip
    email.empty? ? 'isoo@local' : email
  end

  def git_author_name
    name = ENV['GIT_AUTHOR_NAME'].to_s.strip
    name.empty? ? 'ISOO' : name
  end
end
