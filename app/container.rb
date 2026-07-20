# frozen_string_literal: true

require 'pathname'

class Container
  def self.data_path
    App::DATA_PATH
  end

  def self.cache
    @cache ||= CacheStore.build
  end

  def self.storage
    @storage ||= StorageBackend.build(data_path: data_path)
  end

  def self.git
    @git ||= GitService.new(data_path)
  end

  def self.template_id
    id = ENV.fetch('TEMPLATE_ID', 'voca').to_s.strip
    id.empty? ? 'voca' : id
  end

  def self.template_info
    id = template_id
    manifest_path = File.join(App::TEMPLATES_PATH, id, 'manifest.yaml')
    name = id
    if File.file?(manifest_path)
      data = YAML.safe_load_file(manifest_path) || {}
      label = data['name'].to_s.strip
      name = label unless label.empty?
    end
    { id: id, name: name }
  end

  def self.projects
    @projects ||= ProjectCreator.new(data_root: data_path, template_id: template_id, git: storage)
  end

  def self.classified_store(project_root, scope: nil)
    slug = File.basename(project_root)
    scope ||= "project:#{slug}"
    base = ClassifiedFileStore.new(FileStore.new(project_root))
    return base unless cache.enabled?

    CachingClassifiedFileStore.new(base, cache: cache, scope: scope)
  end

  def self.presence_store
    @presence_store ||= PresenceStore.build
  end

  def self.reset!
    @cache = nil
    @presence_store = nil
    @git = nil
    @storage = nil
    @projects = nil
  end
end
