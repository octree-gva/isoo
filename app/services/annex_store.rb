# frozen_string_literal: true

require 'fileutils'
require 'yaml'

class AnnexStore
  def initialize(project_root)
    @root = project_root
    @registry_path = File.join(@root, 'annexes', 'registry.yaml')
    @versions_path = File.join(@root, 'annexes', 'versions.yaml')
    @files_dir = File.join(@root, 'annexes', 'files')
  end

  def ensure!
    FileUtils.mkdir_p(@files_dir)
    write_registry('next_id' => 1, 'annexes' => []) unless File.file?(@registry_path)
    File.write(@versions_path, { 'annexes' => {} }.to_yaml) unless File.file?(@versions_path)
  end

  def create_annex(title:, slug: nil)
    ensure!
    reg = load_registry
    id = reg['next_id']
    reg['next_id'] = id + 1
    label = title.to_s.strip
    label = 'annex' if label.empty?
    slug_source = slug.to_s.strip
    slug_source = label if slug_source.empty?
    slug = slug_source.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-|-$/, '')
    slug = "annex-#{id}" if slug.empty?
    reg['annexes'] << { 'id' => id, 'slug' => slug, 'title' => label }
    write_registry(reg)
    id
  end

  def find(annex_id)
    load_registry['annexes'].find { |a| a['id'] == annex_id }
  end

  def find_by_slug(slug)
    needle = slug.to_s.strip
    return nil if needle.empty?

    load_registry['annexes'].find { |a| a['slug'].to_s == needle }
  end

  def file_for_version(annex_id, version)
    versions(annex_id).find { |v| v['version'] == version.to_i }
  end

  def upload(annex_id:, uploaded_file:, original_name:, document_version: nil)
    ensure!
    reg = load_registry
    annex = reg['annexes'].find { |a| a['id'] == annex_id }
    raise ArgumentError, 'annex not found' unless annex

    vers = load_versions
    key = annex_id.to_s
    vers['annexes'][key] ||= { 'latest' => 0, 'versions' => [] }
    n = vers['annexes'][key]['latest'].to_i + 1
    ext = File.extname(original_name).delete_prefix('.').downcase
    filename = "#{annex_id}-#{annex['slug']}-#{n}.#{ext}"
    dest = File.join(@files_dir, filename)
    File.binwrite(dest, uploaded_file)
    vers['annexes'][key]['latest'] = n
    entry = {
      'version' => n,
      'filename' => filename,
      'original_name' => original_name,
      'uploaded_at' => Time.now.utc.iso8601
    }
    entry['document_version'] = document_version if document_version
    vers['annexes'][key]['versions'] << entry
    File.write(@versions_path, vers.to_yaml)
    filename
  end

  def file_for_document_version(annex_id, document_version)
    versions(annex_id).find { |v| v['document_version'] == document_version }
  end

  def latest_file(annex_id)
    versions(annex_id).find { |v| v['version'] == latest_version(annex_id) }
  end

  def versions(annex_id)
    ensure!
    entry = load_versions['annexes'][annex_id.to_s]
    return [] unless entry

    Array(entry['versions'])
  end

  private

  def latest_version(annex_id)
    load_versions.dig('annexes', annex_id.to_s, 'latest')
  end

  def load_registry
    ensure!
    YAML.safe_load_file(@registry_path)
  end

  def write_registry(data)
    File.write(@registry_path, data.to_yaml)
  end

  def load_versions
    ensure!
    YAML.safe_load_file(@versions_path)
  end
end
