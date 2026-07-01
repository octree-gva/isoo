# frozen_string_literal: true

require 'yaml'

require_relative 'project_version_bump'

class ProjectManifest
  FORM_KIND = 'form'
  FILE_ANNEX_KIND = 'file_annex'

  def self.load(path_or_root, cache: Container.cache)
    path = manifest_path(path_or_root)
    data = if cache.enabled?
             scope = project_scope(path)
             fingerprint = CacheStore.file_fingerprint(path)
             yaml = cache.fetch("manifest:#{fingerprint}", scope: scope, expires_in: 3600) do
               File.read(path, encoding: 'UTF-8')
             end
             YAML.safe_load(yaml) || {}
           else
             YAML.safe_load_file(path) || {}
           end
    manifest = new(path, data)
    manifest.ensure_version!
    manifest
  end

  def self.project_scope(path)
    match = path.match(%r{/projects/([^/]+)/manifest\.yaml\z})
    match ? "project:#{match[1]}" : 'global'
  end

  def self.manifest_path(path_or_root)
    path_or_root.to_s.end_with?('manifest.yaml') ? path_or_root : File.join(path_or_root, 'manifest.yaml')
  end

  attr_reader :path, :data

  def initialize(path, data)
    @path = path
    @data = normalize_data(data || {})
  end

  def name
    data['name']
  end

  def version
    ProjectVersionBump.normalize_version(data['version'])
  end

  def ensure_version!
    normalized = ProjectVersionBump.normalize_version(data['version'])
    current = data['version']
    return if current.is_a?(String) && current == normalized

    data['version'] = normalized
    save!
  end

  def export_title
    "#{name} v#{version}"
  end

  def export_basename
    "#{slugify_name(name)}-v#{version}"
  end

  def bump_version!(significant:)
    data['version'] = ProjectVersionBump.next_version(version, significant: significant)
    save!
    data['version']
  end

  def documents
    singleton_documents
  end

  def singleton_documents
    (data['documents'] || []).reject { |doc| doc['kind'] == FILE_ANNEX_KIND }
  end

  def annexes
    explicit = data['annexes']
    return explicit if explicit.is_a?(Array) && explicit.any?

    (data['documents'] || []).select { |doc| doc['kind'] == FILE_ANNEX_KIND }
  end

  def active_annexes
    annexes.select { |annex| AnnexStatus.active?(annex) }
  end

  def forms
    data.fetch('forms', [])
  end

  def save!
    data['version'] = ProjectVersionBump.normalize_version(data['version'])
    File.write(path, data.to_yaml)
    Container.cache.bump(self.class.project_scope(path)) if Container.cache.enabled?
  end

  def resolve_document(doc_id)
    doc = singleton_documents.find { |d| d['doc_id'] == doc_id }
    return doc if doc

    annex = annexes.find { |d| d['doc_id'] == doc_id }
    return annex if annex

    form, response = find_response(doc_id)
    return nil unless response

    response.merge(
      'kind' => form.fetch('response_kind', 'text'),
      'form_id' => form['doc_id'],
      'title' => response['title'] || response['doc_id']
    )
  end

  def find_form(form_id)
    forms.find { |f| f['doc_id'] == form_id }
  end

  def find_response(doc_id)
    forms.each do |form|
      response = form.fetch('responses', []).find { |r| r['doc_id'] == doc_id }
      return [form, response] if response
    end
    nil
  end

  def add_response!(form_id, response)
    form = find_form(form_id)
    raise ArgumentError, "unknown form: #{form_id}" unless form

    form['responses'] ||= []
    form['responses'] << response
    save!
  end

  def next_response_number(form_id)
    form = find_form(form_id)
    return 1 unless form

    max = form.fetch('responses', []).filter_map do |response|
      match = response['doc_id'].to_s.match(/\A#{Regexp.escape(form_id)}-(\d+)\z/)
      next unless match

      match[1].to_i
    end.max
    (max || 0) + 1
  end

  def find_annex(doc_id)
    annexes.find { |a| a['doc_id'] == doc_id }
  end

  def add_annex!(entry)
    data['annexes'] ||= []
    data['annexes'] << entry
    save!
  end

  def update_annex!(doc_id, attrs)
    annex = find_annex(doc_id)
    raise ArgumentError, "unknown annex: #{doc_id}" unless annex

    attrs.each { |key, value| annex[key.to_s] = value }
    save!
  end

  def soft_delete_annex!(doc_id)
    update_annex!(doc_id, '_deleted_at' => Time.now.utc.iso8601)
  end

  def restore_annex!(doc_id)
    annex = find_annex(doc_id)
    raise ArgumentError, "unknown annex: #{doc_id}" unless annex

    annex.delete('_deleted_at')
    save!
  end

  def next_annex_number
    max = annexes.filter_map do |annex|
      match = annex['doc_id'].to_s.match(/\Aannex-(\d+)\z/)
      next unless match

      match[1].to_i
    end.max
    (max || 0) + 1
  end

  private

  def normalize_data(data)
    data['documents'] = Array(data['documents'])
    data['forms'] = Array(data['forms']).map { |form| normalize_form(form) }
    data['annexes'] = Array(data['annexes']) if data.key?('annexes')
    data
  end

  def normalize_form(form)
    form.merge('responses' => Array(form['responses']))
  end

  def slugify_name(value)
    value.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
  end
end
