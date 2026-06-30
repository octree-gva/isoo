# frozen_string_literal: true

require 'yaml'

class ExportTagRegistry
  def self.default_path
    File.join(App::TEMPLATES_PATH, 'voca', 'export_tags.yaml')
  end

  def self.load(path = default_path)
    return empty unless File.file?(path)

    data = YAML.safe_load_file(path) || {}
    new(data.fetch('tags', []))
  end

  def self.for_project(project_root)
    manifest = ProjectManifest.load(project_root)
    template_id = manifest.data['id'].to_s
    path = File.join(App::TEMPLATES_PATH, template_id, 'export_tags.yaml')
    load(path)
  end

  def self.empty
    new([])
  end

  attr_reader :tags, :ids

  def initialize(tags)
    @tags = Array(tags).map { |tag| tag.transform_keys(&:to_s) }
    @ids = @tags.map { |tag| tag['id'].to_s }.reject(&:empty?)
  end

  def known?(id)
    id.to_s == 'full' || ids.include?(id.to_s)
  end

  def label_for(id)
    tag = tags.find { |entry| entry['id'] == id.to_s }
    tag ? tag['label'].to_s : id.to_s
  end

  def description_for(id)
    tag = tags.find { |entry| entry['id'] == id.to_s }
    tag ? tag['description'].to_s : ''
  end

  def tags_for(*categories)
    wanted = categories.flatten.map(&:to_s).reject(&:empty?)
    return tags if wanted.empty?

    tags.select do |tag|
      scopes = Array(tag['scopes']).map(&:to_s).reject(&:empty?)
      scopes.empty? || wanted.any? { |category| scopes.include?(category) }
    end
  end
end
