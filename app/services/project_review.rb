# frozen_string_literal: true

require 'date'
require 'time'
require 'yaml'

require_relative '../i18n'

class ProjectReview
  STALE_AFTER_MONTHS = 12
  EDITABLE_KINDS = %w[text table].freeze
  OLDEST_DOCUMENTS_LIMIT = 5

  StaleDocument = Struct.new(:doc_id, :title, :kind, :last_updated, keyword_init: true)
  ExpiredReviewDate = Struct.new(
    :doc_id, :title, :column_key, :column_label, :row_label, :review_date, :days_overdue,
    keyword_init: true
  )

  def initialize(manifest:, store:)
    @manifest = manifest
    @store = store
  end

  def stale_documents(as_of: Date.today)
    cutoff = as_of << STALE_AFTER_MONTHS
    all_documents.filter_map do |doc|
      last_updated = document_last_updated(doc)
      next unless last_updated
      next unless last_updated <= cutoff

      StaleDocument.new(
        doc_id: doc['doc_id'],
        title: doc['title'] || doc['doc_id'],
        kind: doc['kind'],
        last_updated: last_updated
      )
    end.sort_by { |item| [item.last_updated, item.title] }
  end

  def expired_review_dates(as_of: Date.today)
    items = []
    all_documents.each do |doc|
      next unless doc['kind'] == 'table'

      data = TableDocumentStore.new(@store).read(doc['path'])
      review_columns = data[:schema]['columns'].select { |col| col['type'] == 'review_date' }
      next if review_columns.empty?

      primary_key = data[:schema]['primary_key']
      data[:rows].each_with_index do |row, index|
        review_columns.each do |col|
          value = row[col['key']].to_s.strip
          next if value.empty?

          date = Date.iso8601(value)
          next if date > as_of

          row_label = if row[primary_key].to_s.strip.empty?
                        IsooI18n.t('a11y.table_row_number', number: index + 1)
                      else
                        row[primary_key]
                      end
          items << ExpiredReviewDate.new(
            doc_id: doc['doc_id'],
            title: doc['title'] || doc['doc_id'],
            column_key: col['key'],
            column_label: col['label'],
            row_label: row_label,
            review_date: date,
            days_overdue: (as_of - date).to_i
          )
        end
      end
    end
    items.sort_by { |item| [item.review_date, item.title, item.row_label] }
  end

  def oldest_editable_documents(limit: OLDEST_DOCUMENTS_LIMIT)
    all_documents.filter_map do |doc|
      next unless EDITABLE_KINDS.include?(doc['kind'])

      last_updated = document_last_updated(doc)
      next unless last_updated

      StaleDocument.new(
        doc_id: doc['doc_id'],
        title: doc['title'] || doc['doc_id'],
        kind: doc['kind'],
        last_updated: last_updated
      )
    end.sort_by { |item| [item.last_updated, item.title.downcase] }.first(limit)
  end

  private

  def all_documents
    docs = @manifest.documents.dup
    @manifest.annexes.each { |annex| docs << annex }
    @manifest.forms.each do |form|
      form.fetch('responses', []).each do |response|
        docs << response.merge(
          'kind' => form.fetch('response_kind', 'text'),
          'title' => response['title'] || response['doc_id']
        )
      end
    end
    docs
  end

  def document_last_updated(doc)
    md_rel = OkfPaths.md(doc['path'])
    return nil unless @store.exist?(md_rel)

    raw = @store.read(md_rel)
    meta, body = FrontMatter.parse(raw)
    dates = []
    dates << parse_date(meta['timestamp'])
    dates << version_control_last_modified(body)
    dates << parse_date(@store.audit(md_rel)['modified_at'])
    dates.compact.max
  end

  def version_control_last_modified(body)
    row = VersionControlWriter.existing_rows(body).last
    return nil unless row

    parts = row.split('|').map(&:strip)
    return nil if parts.length < 3

    parse_date(parts[2])
  end

  def parse_date(value)
    return nil if value.nil? || value.to_s.strip.empty?

    Time.parse(value.to_s).to_date
  rescue ArgumentError
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end
end
