# frozen_string_literal: true

module RoutesGit
  def routes_git(r)
    r.post('sync') { git_sync(r) }
  end

  def git_sync(r)
    return r.halt([404, {}, [t('errors.404.title')]]) unless StorageBackend.git? && GitService.remote_sync_enabled?

    result = self.class.storage.pull!
    rack_session['flash'] = git_sync_flash(result)
    invalidate_after_git_pull if result[:status] == :ok
    r.redirect(env['HTTP_REFERER'] || '/projects')
  end

  def git_sync_flash(result)
    case result[:status]
    when :ok
      message = if result[:empty_remote]
                  t('git.sync_ok_empty')
                else
                  t('git.sync_ok', revision: result[:revision])
                end
      { 'message' => message, 'type' => 'success' }
    when :dirty
      { 'message' => t('git.sync_dirty'), 'type' => 'error' }
    when :disabled
      { 'message' => t('git.sync_disabled'), 'type' => 'error' }
    when :error
      { 'message' => t('git.sync_error', message: result[:message]), 'type' => 'error' }
    end
  end

  def invalidate_after_git_pull
    Container.reset!
    cache = Container.cache
    return unless cache.enabled?

    cache.bump('global')
    ProjectCreator.new(data_root: DATA_PATH).list.each do |project|
      cache.bump("project:#{project[:slug]}")
    end
  end
end
