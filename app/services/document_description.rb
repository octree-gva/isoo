# frozen_string_literal: true

require 'yaml'
require_relative 'front_matter'

class DocumentDescription
  @guidance_cache = {}

  def self.resolve(meta, doc, data_root: App::DATA_PATH, template_id: 'voca', project_root: nil)
    title = doc['title'] || meta['title'] || doc['doc_id'].to_s
    doc_id = doc['doc_id'].to_s
    doc_id = meta.dig('iso27001', 'doc_id').to_s if doc_id.empty?

    candidates = [
      doc['description'],
      project_schema_description(project_root, doc),
      meta['description'],
      project_guidance_for(project_root, doc_id),
      guidance_for(data_root, template_id, doc_id),
      template_md_description(data_root, template_id, doc),
      template_schema_description(data_root, template_id, doc)
    ]

    candidates.each do |candidate|
      text = candidate.to_s.strip
      next if text.empty?
      next if text.casecmp?(title.strip)

      return text
    end
    ''
  end

  def self.guidance_for(data_root, template_id, doc_id)
    return '' if doc_id.empty?

    path = File.join(data_root, 'templates', template_id, 'guidance', 'descriptions.yaml')
    cache = guidance_cache(data_root, template_id, path)
    cache[doc_id]
  end

  def self.project_guidance_for(project_root, doc_id)
    return '' if project_root.to_s.empty? || doc_id.empty?

    path = File.join(project_root, 'guidance', 'descriptions.yaml')
    return '' unless File.file?(path)

    cache = guidance_cache(project_root, 'project', path)
    cache[doc_id].to_s.strip
  end

  def self.project_schema_description(project_root, doc)
    return '' if project_root.to_s.empty? || !doc['path'] || !doc['doc_id']

    path = File.join(project_root, doc['path'], "#{doc['doc_id']}.schema.yaml")
    return '' unless File.file?(path)

    schema = YAML.safe_load_file(path) || {}
    schema['description'].to_s.strip
  rescue Psych::SyntaxError
    ''
  end

  def self.guidance_cache(data_root, template_id, path)
    key = [data_root, template_id].join("\0")
    @guidance_cache[key] ||= File.file?(path) ? YAML.safe_load_file(path) || {} : {}
  end
  private_class_method :guidance_cache

  def self.template_md_description(data_root, template_id, doc)
    path = template_md_path(data_root, template_id, doc)
    return '' unless path && File.file?(path)

    meta, = FrontMatter.parse(File.read(path, encoding: 'UTF-8'))
    meta['description'].to_s.strip
  rescue Psych::SyntaxError
    ''
  end

  def self.template_schema_description(data_root, template_id, doc)
    path = template_schema_path(data_root, template_id, doc)
    return '' unless path && File.file?(path)

    schema = YAML.safe_load_file(path) || {}
    schema['description'].to_s.strip
  rescue Psych::SyntaxError
    ''
  end

  def self.template_md_path(data_root, template_id, doc)
    return nil unless data_root && doc['path'] && doc['doc_id']

    File.join(data_root, 'templates', template_id, doc['path'], "#{doc['doc_id']}.md")
  end

  def self.template_schema_path(data_root, template_id, doc)
    return nil unless data_root && doc['path'] && doc['doc_id']

    File.join(data_root, 'templates', template_id, doc['path'], "#{doc['doc_id']}.schema.yaml")
  end

  private_class_method :template_md_path, :template_schema_path
end
