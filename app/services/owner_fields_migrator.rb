# frozen_string_literal: true

require 'csv'
require 'yaml'

class OwnerFieldsMigrator
  INTERNAL_CSV_KEYS = %w[_row_id _deleted_at].freeze

  def initialize(root)
    @root = root
    @updated_schemas = 0
    @updated_csvs = 0
  end

  attr_reader :updated_schemas, :updated_csvs

  def migrate!
    Dir.glob(File.join(@root, '**', '*.schema.yaml')).sort.each do |schema_path|
      migrate_schema_file(schema_path)
    end
    self
  end

  private

  def migrate_schema_file(schema_path)
    schema = YAML.safe_load_file(schema_path)
    return unless schema.is_a?(Hash)

    changed = false
    if DocumentOwner.needs_owner_sections?(schema) && !DocumentOwner.schema_has_owner?(schema)
      schema['sections'] = Array(schema['sections']) + DocumentOwner.owner_section_definitions
      changed = true
    elsif DocumentOwner.needs_owner_columns?(schema) && !DocumentOwner.schema_has_owner?(schema)
      schema['columns'] = Array(schema['columns']) + DocumentOwner.owner_column_definitions
      changed = true
    end

    return unless changed

    File.write(schema_path, schema.to_yaml)
    @updated_schemas += 1
    migrate_csv_for_schema(schema_path, schema)
  end

  def migrate_csv_for_schema(schema_path, schema)
    return unless DocumentOwner.needs_owner_columns?(schema)

    doc_id = File.basename(schema_path, '.schema.yaml')
    dir = File.dirname(schema_path)
    csv_path = File.join(dir, "#{doc_id}.csv")
    return unless File.file?(csv_path)

    rows = CSV.read(csv_path, headers: true)
    headers = rows.headers
    return if headers.include?(DocumentOwner.owner_name_key)

    expected = schema['columns'].map { |col| col['key'] } + INTERNAL_CSV_KEYS
    content = CSV.generate(write_headers: true, headers: expected) do |csv|
      rows.each do |row|
        csv << expected.map { |key| row[key].to_s }
      end
    end
    File.write(csv_path, content)
    @updated_csvs += 1
  end
end
