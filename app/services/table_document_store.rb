# frozen_string_literal: true

require 'csv'
require 'securerandom'
require 'yaml'

require_relative '../i18n'

class TableDocumentStore
  class ValidationError < ArgumentError; end

  HTTPS_LINK = %r{\Ahttps://.+}i
  def initialize(store)
    @store = store
  end

  def read(doc_path)
    schema = YAML.safe_load(@store.read(OkfPaths.schema(doc_path)))
    csv_path = OkfPaths.csv(doc_path)
    rows = []
    if @store.exist?(csv_path)
      CSV.parse(@store.read(csv_path), headers: true).each do |row|
        rows << row.to_h if row['_deleted_at'].to_s == ''
      end
    end
    md_path = OkfPaths.md(doc_path)
    raw = @store.read(md_path)
    meta, body = FrontMatter.parse(raw)
    version_control_rows = VersionControlWriter.sorted_rows(body)
    { schema: schema, rows: rows, csv_path: csv_path, md_path: md_path, meta: meta,
      version_control_rows: version_control_rows }
  end

  def save_rows(doc_path, rows:, version:, date:, author:, changes:, owner: nil) # rubocop:disable Metrics/ParameterLists
    doc = read(doc_path)
    rows = apply_owner_to_rows(rows, owner) if owner
    write_csv(doc, rows, author)
    bump_md(doc, version, date, author, changes, owner: owner)
  end

  def soft_delete(doc_path, row_id)
    doc = read(doc_path)
    all = load_all_rows(doc[:csv_path])
    all.each { |row| row['_deleted_at'] = Time.now.utc.iso8601 if row['_row_id'] == row_id }
    write_csv(doc, all, nil)
  end

  def add_row(doc_path, attrs)
    doc = read(doc_path)
    all = @store.exist?(doc[:csv_path]) ? load_all_rows(doc[:csv_path]) : []
    row = row_attrs(doc, attrs).merge('_row_id' => SecureRandom.uuid, '_deleted_at' => '')
    owner = DocumentOwner.from_document(meta: doc[:meta], rows: all)
    row = row.merge(owner) if owner[DocumentOwner.owner_name_key] != '' || owner[DocumentOwner.owner_email_key] != ''
    all << row
    write_csv(doc, all, nil)
    row
  end

  def update_row(doc_path, row_id, attrs)
    doc = read(doc_path)
    all = load_all_rows(doc[:csv_path])
    updated = row_attrs(doc, attrs)
    all.each do |row|
      next unless row['_row_id'] == row_id

      updated.each { |key, value| row[key] = value }
    end
    write_csv(doc, all, nil)
    find_row(doc_path, row_id)
  end

  def update_rows_from_params(doc_path, rows_params, author: nil)
    doc = read(doc_path)
    all = load_all_rows(doc[:csv_path])
    all.each do |row|
      next if row['_deleted_at'].to_s != ''

      attrs = rows_params[row['_row_id'].to_s]
      next unless attrs

      updated = row_attrs(doc, attrs)
      updated.each { |key, value| row[key] = value }
    end
    write_csv(doc, all, author)
  end

  def save_fullscreen(doc_path, rows_params:, version:, date:, author:, changes:, owner: nil) # rubocop:disable Metrics/ParameterLists
    update_rows_from_params(doc_path, rows_params, author: author)
    apply_owner!(doc_path, owner) if owner
    doc = read(doc_path)
    bump_md(doc, version, date, author, changes, owner: owner)
  end

  def apply_owner!(doc_path, owner)
    return unless owner

    doc = read(doc_path)
    all = load_all_rows(doc[:csv_path])
    write_csv(doc, apply_owner_to_rows(all, owner), nil)
  end

  def find_row(doc_path, row_id)
    read(doc_path)[:rows].find { |row| row['_row_id'] == row_id }
  end

  private

  def row_attrs(doc, attrs)
    keys = doc[:schema]['columns'].map { |c| c['key'] }
    row = attrs.transform_keys(&:to_s).slice(*keys)
    doc[:schema]['columns'].each { |col| normalize_column!(row, col) }
    row
  end

  def normalize_column!(row, col)
    key = col['key']
    value = row[key]
    case col['type']
    when 'link'
      v = value.to_s.strip
      raise ValidationError, IsooI18n.t('table.link_https_required') if !v.empty? && !v.match?(HTTPS_LINK)
    when 'review_date'
      v = value.to_s.strip
      return if v.empty?

      date = Date.iso8601(v)
      raise ValidationError, IsooI18n.t('table.review_date_must_be_future') if date <= Date.today
    when 'switch'
      row[key] = '0' if value.nil? || value.to_s.strip.empty?
    when 'email'
      validate_email!(value)
    end
  end

  def load_all_rows(csv_path)
    return [] unless @store.exist?(csv_path)

    CSV.parse(@store.read(csv_path), headers: true).map(&:to_h)
  end

  def write_csv(doc, rows, author)
    keys = doc[:schema]['columns'].map { |c| c['key'] } + %w[_row_id _deleted_at]
    content = CSV.generate(write_headers: true, headers: keys) do |csv|
      rows.each { |row| csv << keys.map { |k| row[k] } }
    end
    write_file(doc[:csv_path], content, doc[:meta], author)
  end

  def bump_md(doc, version, date, author, changes, owner: nil)
    raw = @store.read(doc[:md_path])
    meta, body = FrontMatter.parse(raw)
    meta['iso27001'] ||= {}
    meta['iso27001']['version'] = version
    DocumentOwner.write_to_meta!(meta, owner) if owner
    meta['timestamp'] = Time.now.utc.iso8601
    body = VersionControlWriter.append_row(body, version: version, date: date, author: author, changes: changes)
    write_file(doc[:md_path], FrontMatter.dump(meta, body), meta, author)
  end

  def write_file(path, content, meta, author)
    classification = meta.dig('iso27001', 'classification')
    audit = {
      'classification' => classification,
      'version' => meta.dig('iso27001', 'version'),
      'modified_at' => meta['timestamp'] || Time.now.utc.iso8601,
      'modified_by' => author
    }
    if confidential_store?(@store)
      @store.write(path, content, classification: classification, audit: audit)
    else
      @store.write(path, content)
    end
  end

  def validate_email!(value)
    v = value.to_s.strip
    return if v.empty?

    raise ValidationError, IsooI18n.t('owner.email_invalid') unless v.match?(DocumentOwner::EMAIL_PATTERN)
  end

  def apply_owner_to_rows(rows, owner)
    DocumentOwner.propagate_to_rows(rows, owner)
  end

  def confidential_store?(store)
    store.is_a?(ClassifiedFileStore) || store.is_a?(CachingClassifiedFileStore)
  end
end
