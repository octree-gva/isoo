# frozen_string_literal: true

require 'fileutils'
require 'yaml'

class ProjectCreator
  SEED_TABLE_CSVS = %w[
    isms-rasci-matrix-full.csv
    isms-rasci-matrix-basic-accountability-matrix.csv
  ].freeze

  def initialize(data_root:, template_id: 'voca', git: nil)
    @data_root = data_root
    @template_id = template_id
    @git = git
  end

  def create(name:, slug:, author: 'system')
    dest = File.join(@data_root, 'projects', slug)
    raise ArgumentError, 'project exists' if File.directory?(dest)

    src = File.join(@data_root, 'templates', @template_id)
    raise ArgumentError, 'template missing' unless File.directory?(src)

    FileUtils.mkdir_p(File.dirname(dest))
    FileUtils.cp_r(src, dest)
    reset_project(dest, author)
    manifest_path = File.join(dest, 'manifest.yaml')
    if File.file?(manifest_path)
      data = YAML.safe_load_file(manifest_path) || {}
      data['name'] = name
      File.write(manifest_path, data.to_yaml)
    end
    encrypt_confidential(dest, author)
    transform_manifest_for_forms(dest)
    transform_manifest_for_annexes(dest)
    commit_project_create(slug)
    { slug: slug, name: name }
  end

  def list
    dir = File.join(@data_root, 'projects')
    return [] unless File.directory?(dir)

    Dir.children(dir).filter_map do |slug|
      path = File.join(dir, slug)
      next unless File.directory?(path)

      manifest = File.join(path, 'manifest.yaml')
      name = slug
      if File.file?(manifest)
        data = YAML.safe_load_file(manifest)
        name = data['name'] || slug
      end
      { slug: slug, name: name }
    end
  end

  def prune_except!(keep_slug:)
    dir = File.join(@data_root, 'projects')
    return [] unless File.directory?(dir)

    Dir.children(dir).filter_map do |slug|
      next if slug == '.gitkeep' || slug == keep_slug

      path = File.join(dir, slug)
      next unless File.directory?(path)

      FileUtils.rm_rf(path)
      slug
    end
  end

  private

  def reset_project(dest, _author)
    Time.now.utc.strftime('%Y-%m-%d')
    Dir.glob(File.join(dest, '**', '*.md')).each do |md|
      next if File.basename(md) == 'index.md'

      text = File.read(md, encoding: 'UTF-8')
      text = text.sub(/version: ".*?"/, 'version: "0.1.0"')
      File.write(md, text, encoding: 'UTF-8')
    end

    Dir.glob(File.join(dest, '**', '*.csv')).each do |csv|
      next if SEED_TABLE_CSVS.include?(File.basename(csv))

      lines = File.readlines(csv, encoding: 'UTF-8')
      File.write(csv, lines[0], encoding: 'UTF-8') if lines.any?
    end
  end

  def transform_manifest_for_forms(dest)
    manifest_path = File.join(dest, 'manifest.yaml')
    data = YAML.safe_load_file(manifest_path) || {}
    docs = data['documents'] || []
    forms = []
    singletons = []

    docs.each do |doc|
      if doc['kind'] == ProjectManifest::FORM_KIND
        remove_form_stamp(dest, doc)
        forms << form_entry(doc, dest)
      else
        singletons << doc
      end
    end

    data['documents'] = singletons
    data['forms'] = forms
    File.write(manifest_path, data.to_yaml)
  end

  def transform_manifest_for_annexes(dest)
    manifest_path = File.join(dest, 'manifest.yaml')
    data = YAML.safe_load_file(manifest_path) || {}
    docs = data['documents'] || []
    annexes = []
    singletons = []

    docs.each do |doc|
      if doc['kind'] == ProjectManifest::FILE_ANNEX_KIND
        annexes << annex_entry(doc, dest)
      else
        singletons << doc
      end
    end

    data['documents'] = singletons
    data['annexes'] = annexes if annexes.any?
    File.write(manifest_path, data.to_yaml)
  end

  def annex_entry(doc, dest)
    entry = {
      'doc_id' => doc['doc_id'],
      'path' => doc['path'],
      'title' => doc['title'],
      'kind' => ProjectManifest::FILE_ANNEX_KIND,
      'asset_kind' => 'document'
    }
    entry['seq'] = doc['seq'] if doc['seq']
    schema_path = File.join(dest, doc['path'], "#{doc['doc_id']}.schema.yaml")
    if File.file?(schema_path)
      schema = YAML.safe_load_file(schema_path) || {}
      description = schema['description'].to_s.strip
      entry['description'] = description unless description.empty?
    end
    entry
  end

  def form_entry(doc, dest)
    entry = {
      'doc_id' => doc['doc_id'],
      'path' => doc['path'],
      'title' => doc['title'],
      'response_kind' => doc['response_kind'] || 'text',
      'responses' => []
    }
    entry['seq'] = doc['seq'] if doc['seq']
    schema_path = File.join(dest, doc['path'], "#{doc['doc_id']}.schema.yaml")
    if File.file?(schema_path)
      schema = YAML.safe_load_file(schema_path) || {}
      description = schema['description'].to_s.strip
      entry['description'] = description unless description.empty?
    end
    entry
  end

  def remove_form_stamp(dest, doc)
    base = File.join(dest, doc['path'])
    id = doc['doc_id']
    %w[.md .csv].each do |ext|
      path = File.join(base, "#{id}#{ext}")
      File.delete(path) if File.file?(path)
    end
  end

  def commit_project_create(slug)
    @git&.commit("project: create #{slug}")
  rescue StandardError => e
    warn "[ProjectCreator] git commit failed for #{slug}: #{e.message}"
  end

  def encrypt_confidential(dest, author)
    return unless ENV['ENCRYPTION_SECRET']

    store = ClassifiedFileStore.new(FileStore.new(dest))
    encrypt_md_files(dest, store, author)
    encrypt_csv_files(dest, store, author)
  end

  def encrypt_md_files(dest, store, author)
    Dir.glob(File.join(dest, '**', '*.md')).each do |abs|
      rel = abs.delete_prefix("#{dest}/")
      next if rel == 'index.md'

      raw = File.read(abs, encoding: 'UTF-8')
      meta, = FrontMatter.parse(raw)
      encrypt_if_confidential(store, rel, raw, meta, author)
    end
  end

  def encrypt_csv_files(dest, store, author)
    Dir.glob(File.join(dest, '**', '*.csv')).each do |abs|
      rel = abs.delete_prefix("#{dest}/")
      md_rel = rel.sub(/\.csv\z/, '.md')
      next unless store.exist?(md_rel)

      meta, = FrontMatter.parse(store.read(md_rel))
      encrypt_if_confidential(store, rel, File.read(abs, encoding: 'UTF-8'), meta, author)
    end
  end

  def encrypt_if_confidential(store, rel, content, meta, author)
    classification = meta.dig('iso27001', 'classification')
    return unless DocumentCipher.confidential?(classification)

    store.write(rel, content, classification: classification, audit: audit_fields(meta, author, classification))
  end

  def audit_fields(meta, author, classification)
    {
      'classification' => classification,
      'version' => meta.dig('iso27001', 'version'),
      'modified_at' => meta['timestamp'] || Time.now.utc.iso8601,
      'modified_by' => author
    }
  end
end
