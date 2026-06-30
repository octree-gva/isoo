# frozen_string_literal: true

require 'yaml'

class AnnexDocumentStore
  def initialize(store)
    @store = store
  end

  def read(doc_path)
    raw = @store.read(OkfPaths.md(doc_path))
    meta, body = FrontMatter.parse(raw)
    { meta: meta, body: body }
  end

  def set_annex_id(doc_path, annex_id, author: 'system')
    data = read(doc_path)
    data[:meta]['iso27001'] ||= {}
    data[:meta]['iso27001']['annex_id'] = annex_id
    write(doc_path, data[:meta], data[:body], author: author)
  end

  def save_metadata(doc_path, title:, description:, version:, date:, author:, changes:, export_tags: nil)
    data = read(doc_path)
    meta = data[:meta]
    meta['title'] = title
    meta['description'] = description
    meta['timestamp'] = Time.now.utc.iso8601
    meta['iso27001'] ||= {}
    meta['iso27001']['version'] = version
    body = VersionControlWriter.append_row(data[:body], version: version, date: date, author: author,
                                                        changes: changes)
    write(doc_path, meta, body, author: author)
    update_schema_description(doc_path, meta, description, author: author)
    update_schema_export_tags(doc_path, meta, export_tags, author: author) unless export_tags.nil?
  end

  private

  def write(doc_path, meta, body, author:)
    path = OkfPaths.md(doc_path)
    content = FrontMatter.dump(meta, body)
    classification = meta.dig('iso27001', 'classification')
    if classified_store?
      @store.write(path, content, classification: classification, audit: audit_payload(meta, author))
    else
      @store.write(path, content)
    end
  end

  def classified_store?
    @store.is_a?(ClassifiedFileStore) || @store.is_a?(CachingClassifiedFileStore)
  end

  def audit_payload(meta, author)
    {
      'classification' => meta.dig('iso27001', 'classification'),
      'version' => meta.dig('iso27001', 'version'),
      'modified_at' => meta['timestamp'],
      'modified_by' => author
    }
  end

  def update_schema_description(doc_path, meta, description, author:)
    schema_name = meta.dig('iso27001', 'schema')
    return unless schema_name

    schema_path = File.join(doc_path, schema_name)
    return unless @store.exist?(schema_path)

    schema = YAML.safe_load(@store.read(schema_path)) || {}
    schema['description'] = description
    write_schema(doc_path, schema_path, meta, schema, author: author)
  end

  def update_schema_export_tags(doc_path, meta, export_tags, author:)
    schema_name = meta.dig('iso27001', 'schema')
    return unless schema_name

    schema_path = File.join(doc_path, schema_name)
    return unless @store.exist?(schema_path)

    schema = YAML.safe_load(@store.read(schema_path)) || {}
    tags = Array(export_tags).map(&:to_s).reject(&:empty?).uniq.sort
    if tags.empty?
      schema.delete('export_tags')
    else
      schema['export_tags'] = tags
    end
    write_schema(doc_path, schema_path, meta, schema, author: author)
  end

  def write_schema(_doc_path, schema_path, meta, schema, author:)
    content = schema.to_yaml
    classification = meta.dig('iso27001', 'classification')
    if classified_store?
      @store.write(schema_path, content, classification: classification, audit: audit_payload(meta, author))
    else
      @store.write(schema_path, content)
    end
  end
end
