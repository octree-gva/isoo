# frozen_string_literal: true

require 'csv'
require 'yaml'

class AnnexReferenceIndex
  Entry = Struct.new(:doc, :kind, keyword_init: true)

  def initialize(manifest, store:)
    @manifest = manifest
    @store = store
    @by_annex = build_index
  end

  def referencing(annex_doc_id)
    @by_annex[annex_doc_id.to_s.downcase] || []
  end

  def referencing_entries(annex_doc_id)
    referencing(annex_doc_id).map do |entry|
      {
        'doc_id' => entry.doc['doc_id'],
        'title' => entry.doc['title'].to_s.strip.empty? ? entry.doc['doc_id'] : entry.doc['title'],
        'kind' => entry.kind.to_s
      }
    end
  end

  private

  def build_index
    index = Hash.new { |hash, key| hash[key] = [] }

    each_entry do |entry|
      texts_for(entry).each do |text|
        AnnexReference.extract(text).each do |ref_id|
          index[ref_id] << entry unless index[ref_id].any? { |item| item.doc['doc_id'] == entry.doc['doc_id'] }
        end
      end
    end

    index
  end

  def each_entry
    @manifest.documents.each do |doc|
      yield Entry.new(doc: doc, kind: document_kind(doc))
    end

    @manifest.forms.each do |form|
      form.fetch('responses', []).each do |response|
        yield Entry.new(doc: response.merge('form_id' => form['doc_id']), kind: :form_response)
      end
    end
  end

  def document_kind(doc)
    schema_path = OkfPaths.schema(doc['path'])
    return :document unless @store.exist?(schema_path)

    schema = YAML.safe_load(@store.read(schema_path)) || {}
    schema['kind'] == 'table' ? :table : :document
  rescue Psych::SyntaxError
    :document
  end

  def texts_for(entry)
    path = entry.doc['path'].to_s
    md_path = OkfPaths.md(path)
    return [] unless @store.exist?(md_path)

    raw = @store.read(md_path)
    meta, body = FrontMatter.parse(raw)
    body = VersionControlWriter.strip_block(body)
    texts = [body]
    texts << meta['description'].to_s if entry.kind != :form_response && file_annex_path?(path)

    csv_path = OkfPaths.csv(path)
    if @store.exist?(csv_path)
      schema = load_schema(path, entry)
      texts.concat(textarea_values(@store.read(csv_path), schema))
    end

    texts
  rescue Psych::SyntaxError
    []
  end

  def load_schema(path, entry)
    schema_path = if path.include?('/responses/') && entry.doc['form_id']
                    form = @manifest.find_form(entry.doc['form_id'])
                    form ? OkfPaths.schema(form['path']) : OkfPaths.schema(path)
                  else
                    OkfPaths.schema(path)
                  end
    return nil unless @store.exist?(schema_path)

    YAML.safe_load(@store.read(schema_path))
  rescue Psych::SyntaxError
    nil
  end

  def textarea_values(csv_text, schema)
    return [] unless schema

    table = CSV.parse(csv_text, headers: true)
    keys = textarea_column_keys(schema)
    return [] if keys.empty?

    table.flat_map do |row|
      next [] if row['_deleted_at'].to_s != ''

      keys.map { |key| row[key].to_s }.reject(&:empty?)
    end
  end

  def textarea_column_keys(schema)
    case schema['kind']
    when 'table'
      Array(schema['columns']).filter_map do |col|
        col['key'].to_s if textarea_column?(col)
      end
    when 'text', 'form'
      Array(schema['sections']).filter_map do |sec|
        sec['key'].to_s if sec['editable'] != false && textarea_section?(sec)
      end
    else
      []
    end
  end

  def textarea_column?(col)
    type = col['type'].to_s
    field_type = col['field_type'].to_s
    type == 'textarea' || field_type == 'textarea'
  end

  def textarea_section?(sec)
    field_type = sec['field_type'].to_s
    field_type.empty? || field_type == 'textarea'
  end

  def file_annex_path?(path)
    path.start_with?('annexes/')
  end
end
