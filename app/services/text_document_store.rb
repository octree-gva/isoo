# frozen_string_literal: true

require 'yaml'

class TextDocumentStore
  def initialize(store)
    @store = store
  end

  def read(doc_path)
    md_path = OkfPaths.md(doc_path)
    raw = @store.read(md_path)
    meta, body = FrontMatter.parse(raw)
    version_control_rows = VersionControlWriter.sorted_rows(body)
    body = VersionControlWriter.strip_block(body)
    schema = YAML.safe_load(@store.read(OkfPaths.schema(doc_path)))
    fields = extract_fields(body, schema)
    { meta: meta, body: body, schema: schema, md_path: md_path, fields: fields,
      version_control_rows: version_control_rows }
  end

  def save(doc_path, fields:, version: nil, date: nil, author: nil, changes: nil, record_version: true)
    md_path = OkfPaths.md(doc_path)
    schema = YAML.safe_load(@store.read(OkfPaths.schema(doc_path)))
    DocumentOwner.validate_text_fields!(fields, schema: schema)
    raw = @store.read(md_path)
    meta, raw_body = FrontMatter.parse(raw)
    content = build_content_body(fields, schema)

    if record_version
      body = VersionControlWriter.append_row(
        raw_body, version: version, date: date, author: author, changes: changes, content: content
      )
      meta['iso27001'] ||= {}
      meta['iso27001']['version'] = version
    else
      body = content
    end

    DocumentOwner.write_to_meta!(meta, DocumentOwner.from_fields(fields))
    meta['timestamp'] = Time.now.utc.iso8601
    write_md(md_path, FrontMatter.dump(meta, body), meta, author: author)
  end

  def build_content_body(fields, schema)
    body = +''
    schema['sections'].each do |sec|
      markers = heading_markers(sec['level'])
      next unless markers

      if sec['editable'] == false
        body += "#{markers} #{sec['label']}\n\n" if sec['role'] == 'title'
        next
      end

      val = fields[sec['key']].to_s
      body += "#{markers} #{sec['label']}\n\n#{val}\n\n"
    end
    body
  end

  def extract_fields(body, schema)
    blocks = section_blocks(body)
    fields = {}
    schema['sections'].each do |sec|
      next if sec['editable'] == false

      block = blocks.find { |b| b[:level] == sec['level'] && b[:label] == sec['label'] }
      fields[sec['key']] = block ? block[:content].strip : ''
    end
    fields
  end

  def section_blocks(body)
    blocks = []
    lines = body.lines
    i = 0
    while i < lines.length
      if (m = lines[i].match(/\A(\#{1,3})\s+(.+?)\s*\z/))
        level = heading_level(m[1])
        label = m[2].strip
        i += 1
        i += 1 while i < lines.length && lines[i].strip.empty?
        content_start = i
        i += 1 while i < lines.length && !lines[i].match(/\A\#{1,3}\s+/)
        blocks << { level: level, label: label, content: lines[content_start...i].join }
      else
        i += 1
      end
    end
    blocks
  end

  def heading_markers(level)
    { 'h1' => '#', 'h2' => '##', 'h3' => '###' }[level]
  end

  def heading_level(markers)
    { '#' => 'h1', '##' => 'h2', '###' => 'h3' }[markers] || 'h2'
  end

  def confidential_store?(store)
    store.is_a?(ClassifiedFileStore) || store.is_a?(CachingClassifiedFileStore)
  end

  private

  def write_md(path, content, meta, author:)
    classification = meta.dig('iso27001', 'classification')
    audit = audit_payload(meta, author)
    if confidential_store?(@store)
      @store.write(path, content, classification: classification, audit: audit)
    else
      @store.write(path, content)
    end
  end

  def audit_payload(meta, author)
    {
      'classification' => meta.dig('iso27001', 'classification'),
      'version' => meta.dig('iso27001', 'version'),
      'modified_at' => meta['timestamp'],
      'modified_by' => author
    }
  end
end
