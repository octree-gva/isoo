# frozen_string_literal: true

module RoutesProjectSettings
  SETTINGS_TABS = %w[general mcp].freeze

  def routes_project_settings(r, slug)
    r.is do
      r.get { render_project_settings(r, slug) }
    end
    r.post('general') { update_project_general(r, slug) }
    r.post('mcp') { update_project_mcp(r, slug) }
    r.on('mcp', 'accesses') do
      r.is { r.post { create_mcp_access(r, slug) } }
      r.on(String) do |access_id|
        r.post('revoke') { revoke_mcp_access(r, slug, access_id) }
      end
    end
  end

  def render_project_settings(r, slug)
    tab = r.params['tab'].to_s
    tab = 'general' unless SETTINGS_TABS.include?(tab)
    @settings_tab = tab
    mcp_store = McpAccessStore.new(File.join(App::DATA_PATH, 'projects', slug))
    @mcp_enabled = mcp_store.enabled?
    @mcp_accesses = mcp_store.list
    @export_tag_registry = ExportTagRegistry.for_project(File.join(App::DATA_PATH, 'projects', slug))
    @mcp_endpoint = "#{r.base_url}/projects/#{slug}/mcp"
    @content_class = 'max-w-3xl'
    @plain_token = rack_session.delete('mcp_plain_token')
    @plain_token_name = rack_session.delete('mcp_plain_token_name')
    view('projects/settings')
  end

  def update_project_general(r, slug)
    name = r.params['name'].to_s.strip
    description = r.params['description'].to_s
    if name.empty?
      flash_error(t('errors.details.name_required'))
      return r.redirect("/projects/#{slug}/settings?tab=general")
    end

    @manifest.update_general!(name: name, description: description)
    self.class.storage.flush!("settings: update general for #{slug}")
    flash_success('toast.project_settings_saved')
    r.redirect("/projects/#{slug}/settings?tab=general")
  rescue ArgumentError => e
    flash_error(e.message)
    r.redirect("/projects/#{slug}/settings?tab=general")
  end

  def update_project_mcp(r, slug)
    store = McpAccessStore.new(File.join(App::DATA_PATH, 'projects', slug))
    store.enabled = r.params['enabled'].to_s == '1'
    self.class.storage.flush!("settings: mcp enabled=#{store.enabled?} for #{slug}")
    flash_success('toast.project_settings_saved')
    r.redirect("/projects/#{slug}/settings?tab=mcp")
  end
end
