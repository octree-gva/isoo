# frozen_string_literal: true

require_relative 'storage_backend'
require_relative 'git_service'

class GitStorageBackend
  def initialize(data_path: DataLayout::DATA_PATH, git: nil)
    @data_path = File.expand_path(data_path)
    @git = git || GitService.new(@data_path)
  end

  def name
    'git'
  end

  # rubocop:disable Naming/PredicateMethod -- bang API returns success boolean
  def check!
    StorageBackend.ensure_writable_data_path!(@data_path)
    unless system('git', '--version', out: File::NULL, err: File::NULL)
      raise StorageBackend::PreconditionError, 'git binary not found on PATH'
    end

    @git.ensure_repo!
    if GitService.remote_sync_enabled?
      remote = ENV.fetch('GIT_REMOTE_URL').strip
      ok = system('git', 'ls-remote', remote, 'HEAD', out: File::NULL, err: File::NULL)
      raise StorageBackend::PreconditionError, "git remote not reachable: #{remote}" unless ok
    end
    true
  end
  # rubocop:enable Naming/PredicateMethod

  def flush!(message)
    @git.commit(message)
  end

  alias commit flush!

  def pull!
    @git.pull
  end
end
