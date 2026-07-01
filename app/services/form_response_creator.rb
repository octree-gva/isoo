# frozen_string_literal: true

require 'fileutils'
require 'yaml'

require_relative '../i18n'

class FormResponseCreator
  def initialize(data_root:, template_id: 'voca', git: nil)
    @data_root = data_root
    @template_id = template_id
    @template_root = File.join(data_root, 'templates', template_id)
    @git = git
  end

  def create(project_slug:, form_id:, author: 'system', record_version: true)
    project_root = File.join(@data_root, 'projects', project_slug)
    manifest = ProjectManifest.load(project_root)
    form = manifest.find_form(form_id)
    raise ArgumentError, "unknown form: #{form_id}" unless form

    response = build_response(manifest, form, form_id, author)
    write_response(project_root, form, response, form_id, author, record_version: record_version)
    manifest.add_response!(form_id, response.slice('doc_id', 'path', 'title'))
    manifest.bump_version!(significant: false)
    encrypt_confidential(project_root, response['path'], author)
    @git&.commit("#{form_id}: create response #{response['doc_id']}")
    response['doc_id']
  end

  def build_response(manifest, form, form_id, author)
    number = manifest.next_response_number(form_id)
    doc_id = "#{form_id}-#{number}"
    {
      'doc_id' => doc_id,
      'path' => "#{form['path']}/responses/#{doc_id}",
      'title' => "#{form['title'] || form_id} #{number}",
      'response_kind' => form.fetch('response_kind', 'text'),
      'author' => author
    }
  end

  def write_response(project_root, form, response, form_id, author, record_version: true)
    copy_from_template(
      project_root: project_root,
      template: {
        form_id: form_id,
        template_path: form['path'],
        response_doc_id: response['doc_id'],
        response_path: response['path'],
        response_kind: response['response_kind'],
        author: author,
        record_version: record_version
      }
    )
  end

  private

  def copy_from_template(project_root:, template:)
    form_id = template.fetch(:form_id)
    template_path = template.fetch(:template_path)
    response_doc_id = template.fetch(:response_doc_id)
    response_path = template.fetch(:response_path)
    response_kind = template.fetch(:response_kind)
    author = template.fetch(:author)
    record_version = template.fetch(:record_version, true)

    src_base = File.join(@template_root, template_path, form_id)
    dest_dir = File.join(project_root, response_path)
    FileUtils.mkdir_p(dest_dir)

    FileUtils.cp("#{src_base}.schema.yaml", File.join(dest_dir, "#{response_doc_id}.schema.yaml"))
    transform_response_schema(File.join(dest_dir, "#{response_doc_id}.schema.yaml"), response_kind)
    write_response_markdown(src_base, dest_dir, response_doc_id, response_kind, author, record_version: record_version)
    copy_response_csv(src_base, dest_dir, response_doc_id) if response_kind == 'table'
  end

  def write_response_markdown(src_base, dest_dir, response_doc_id, response_kind, author, record_version: true)
    raw_md = File.read("#{src_base}.md", encoding: 'UTF-8')
    meta, body = FrontMatter.parse(raw_md)
    meta['iso27001'] ||= {}
    meta['iso27001']['doc_id'] = response_doc_id
    meta['iso27001']['kind'] = response_kind
    meta['iso27001']['version'] = '0.1.0'
    meta['iso27001']['schema'] = "#{response_doc_id}.schema.yaml"
    meta['iso27001']['data'] = response_kind == 'table' ? "#{response_doc_id}.csv" : nil
    meta['timestamp'] = Time.now.utc.iso8601

    body = if record_version
             reset_version_control(body, author)
           else
             VersionControlWriter.strip_block(body)
           end
    File.write(File.join(dest_dir, "#{response_doc_id}.md"), FrontMatter.dump(meta, body), encoding: 'UTF-8')
  end

  def transform_response_schema(path, response_kind)
    schema = YAML.safe_load_file(path)
    return unless schema['kind'] == 'form'

    schema['kind'] = response_kind
    schema.delete('response_kind')
    File.write(path, schema.to_yaml)
  end

  def copy_response_csv(src_base, dest_dir, response_doc_id)
    csv_src = "#{src_base}.csv"
    FileUtils.cp(csv_src, File.join(dest_dir, "#{response_doc_id}.csv")) if File.file?(csv_src)
  end

  def reset_version_control(body, author)
    date = Time.now.utc.strftime('%Y-%m-%d')
    body = VersionControlWriter.strip_block(body)
    VersionControlWriter.append_row(
      body,
      version: '0.1.0',
      date: date,
      author: author,
      changes: IsooI18n.t('docs.version_control.first_created')
    )
  end

  def encrypt_confidential(project_root, response_path, author)
    return unless ENV['ENCRYPTION_SECRET']

    store = ClassifiedFileStore.new(FileStore.new(project_root))
    md_rel = OkfPaths.md(response_path)
    return unless store.exist?(md_rel)

    raw = store.read(md_rel)
    meta, = FrontMatter.parse(raw)
    classification = meta.dig('iso27001', 'classification')
    return unless DocumentCipher.confidential?(classification)

    store.write(md_rel, raw, classification: classification, audit: {
                  'classification' => classification,
                  'version' => meta.dig('iso27001', 'version'),
                  'modified_at' => meta['timestamp'] || Time.now.utc.iso8601,
                  'modified_by' => author
                })

    csv_rel = OkfPaths.csv(response_path)
    return unless store.exist?(csv_rel)

    store.write(csv_rel, store.read(csv_rel), classification: classification, audit: {
                  'classification' => classification,
                  'version' => meta.dig('iso27001', 'version'),
                  'modified_at' => meta['timestamp'] || Time.now.utc.iso8601,
                  'modified_by' => author
                })
  end
end
