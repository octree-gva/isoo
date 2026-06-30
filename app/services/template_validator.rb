# frozen_string_literal: true

require 'csv'
require 'yaml'

class TemplateValidator
  ROOT = File.expand_path('../..', __dir__)
  SCHEMA_JSON = File.join(ROOT, 'spec/document.schema.json')

  attr_reader :errors

  def initialize(bundle_path)
    @bundle = bundle_path
    @store = FileStore.new(bundle_path)
    @loader = SchemaLoader.new(@store, SCHEMA_JSON)
    @errors = []
  end

  def valid?
    validate
    errors.empty?
  end

  def validate
    @errors = []
    manifest = load_manifest
    manifest.fetch('documents', []).each { |doc| validate_document(doc) }
    errors
  end

  private

  def load_manifest
    path = File.join(@bundle, 'manifest.yaml')
    raise ArgumentError, "missing manifest: #{path}" unless File.file?(path)

    YAML.safe_load_file(path)
  end

  def validate_document(doc)
    doc_id = doc['doc_id']
    path = doc['path']
    kind = doc['kind']
    base = File.join(@bundle, path)

    unless File.directory?(base)
      errors << "missing directory: #{path}"
      return
    end

    md = File.join(base, "#{doc_id}.md")
    schema_rel = "#{path}/#{doc_id}.schema.yaml"
    errors << "missing markdown: #{path}/#{doc_id}.md" unless File.file?(md)
    errors << "missing schema: #{schema_rel}" unless @store.exist?(schema_rel)

    return unless @store.exist?(schema_rel)

    schema = @loader.load(schema_rel)
    validate_kind_match(doc_id, kind, doc, schema)
  rescue ArgumentError, Psych::SyntaxError => e
    errors << "#{doc_id}: #{e.message}"
  end

  def validate_kind_match(doc_id, kind, doc, schema)
    if kind == ProjectManifest::FORM_KIND
      unless schema['kind'] == ProjectManifest::FORM_KIND
        errors << "kind mismatch #{doc_id}: manifest=#{kind} schema=#{schema['kind']}"
        return
      end

      response_kind = doc['response_kind'] || schema['response_kind']
      if response_kind != schema['response_kind']
        errors << "kind mismatch #{doc_id}: response_kind=#{response_kind} schema=#{schema['response_kind']}"
      end
      validate_table_csv(doc['path'], doc_id, schema) if response_kind == 'table'
      return
    end

    errors << "kind mismatch #{doc_id}: manifest=#{kind} schema=#{schema['kind']}" if kind != schema['kind']
    validate_table_csv(doc['path'], doc_id, schema) if schema['kind'] == 'table'
  end

  def validate_table_csv(path, doc_id, schema)
    csv_rel = "#{path}/#{doc_id}.csv"
    errors << "missing csv: #{csv_rel}" unless @store.exist?(csv_rel)
    return unless @store.exist?(csv_rel)

    header = CSV.parse_line(@store.read(csv_rel))
    expected = schema['columns'].map { |c| c['key'] } + schema['_internal'].map { |c| c['key'] }
    return if header == expected

    errors << "csv header mismatch #{csv_rel}: expected #{expected.join(',')}, got #{header&.join(',')}"
  end
end
