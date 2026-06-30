# frozen_string_literal: true

require 'cgi'
require 'csv'

require_relative '../i18n'
require_relative 'annex_reference'
require_relative 'markdown_renderer'

class ExportContent
  INTERNAL_COLUMNS = %w[_row_id _deleted_at].freeze
  SCHEMA_SECTION = /\n# Schema\b[\s\S]*\z/

  def self.demote_headings(markdown, extra_levels: 1)
    return '' if markdown.to_s.empty?

    markdown.gsub(/^(\#{1,6})(\s+)/) do
      level = [Regexp.last_match(1).length + extra_levels, 6].min
      ('#' * level) + Regexp.last_match(2)
    end
  end

  def self.csv_to_markdown(csv_text, schema: nil, annex_resolver: nil, link_resolver: nil)
    return '' if csv_text.to_s.strip.empty?

    table = CSV.parse(csv_text, headers: true)
    return '' if table.empty?

    headers = table.headers.compact.map(&:to_s).reject { |h| INTERNAL_COLUMNS.include?(h) }
    return '' if headers.empty?

    columns_by_key = column_index(schema)
    lines = []
    lines << "| #{headers.map { |h| escape_cell(h) }.join(' | ')} |"
    lines << "| #{headers.map { '---' }.join(' | ')} |"
    table.each do |row|
      next if row['_deleted_at'].to_s != ''

      lines << "| #{headers.map do |h|
        escape_cell(format_markdown_cell(row[h], columns_by_key[h], annex_resolver: annex_resolver,
                                                                    link_resolver: link_resolver))
      end.join(' | ')} |"
    end
    lines.join("\n")
  end

  def self.csv_to_html(csv_text, schema: nil, annex_resolver: nil, link_resolver: nil)
    return '' if csv_text.to_s.strip.empty?

    table = CSV.parse(csv_text, headers: true)
    return '' if table.empty?

    raw_headers = table.headers.compact.map(&:to_s).reject { |h| INTERNAL_COLUMNS.include?(h) }
    return '' if raw_headers.empty?

    columns = schema ? legend_columns(schema, raw_headers) : raw_headers.map { |key| { 'key' => key, 'label' => key } }
    return '' if columns.empty?

    keys = columns.map { |col| col['key'].to_s }
    html = +'<table class="export-table"><thead><tr>'
    columns.each do |col|
      html << "<th>#{CGI.escapeHTML(column_label(col))}</th>"
    end
    html << '</tr></thead><tbody>'
    table.each do |row|
      next if row['_deleted_at'].to_s != ''

      html << '<tr>'
      keys.each do |key|
        col = columns.find { |column| column['key'].to_s == key }
        html << "<td>#{format_html_cell(row[key], col, annex_resolver: annex_resolver,
                                                       link_resolver: link_resolver)}</td>"
      end
      html << '</tr>'
    end
    html << '</tbody></table>'
    html
  end

  def self.escape_cell(value)
    value.to_s.gsub('|', '\\|').tr("\n", ' ')
  end

  def self.textarea_column?(column)
    return false unless column.is_a?(Hash)

    column['type'].to_s == 'textarea' || column['field_type'].to_s == 'textarea'
  end

  def self.format_markdown_cell(value, column, annex_resolver:, link_resolver:)
    text = value.to_s
    return text unless column && textarea_column?(column)

    text = AnnexReference.rewrite_markdown(text, resolver: annex_resolver) if annex_resolver
    text = link_resolver.rewrite_markdown(text) if link_resolver
    text
  end

  def self.format_html_cell(value, column, annex_resolver:, link_resolver:)
    text = value.to_s
    if column && textarea_column?(column)
      text = AnnexReference.rewrite_markdown(text, resolver: annex_resolver) if annex_resolver
      text = link_resolver.rewrite_markdown(text) if link_resolver
      html = MarkdownRenderer.to_html(text)
      html = link_resolver.rewrite_html(html) if link_resolver
      html
    else
      CGI.escapeHTML(text)
    end
  end

  def self.column_index(schema)
    return {} unless schema.is_a?(Hash)

    Array(schema['columns']).to_h do |col|
      [col['key'].to_s, col]
    end
  end

  def self.column_heading(key, columns_by_key)
    col = columns_by_key[key]
    col ? column_label(col) : key
  end

  def self.strip_schema_section(markdown)
    text = markdown.to_s
    return text unless text.match?(SCHEMA_SECTION)

    text.sub(SCHEMA_SECTION, '').rstrip
  end

  def self.version_control_table_html(body, current_version: nil, meta: nil, audit: nil)
    rows = version_rows_from_body(body)
    rows = fallback_version_rows(meta: meta, audit: audit) if rows.empty?

    current = current_version.to_s
    if current.empty?
      current = audit.is_a?(Hash) ? audit['version'].to_s : ''
      current = meta.dig('iso27001', 'version').to_s if current.empty? && meta.is_a?(Hash)
    end

    render_version_table(rows, current_version: current)
  end

  def self.version_rows_from_body(body)
    return [] unless body.to_s.include?(VersionControlWriter::HEADER)

    version_control_rows(body)
  end

  def self.fallback_version_rows(meta:, audit: nil)
    version = audit.is_a?(Hash) ? audit['version'].to_s : ''
    version = meta.dig('iso27001', 'version').to_s if version.empty? && meta.is_a?(Hash)
    return [] if version.empty?

    modified = format_version_date(audit.is_a?(Hash) ? audit['modified_at'] : nil)
    modified = format_version_date(meta['timestamp']) if modified.empty? && meta.is_a?(Hash)

    author = audit.is_a?(Hash) ? audit['modified_by'].to_s : ''
    author = IsooI18n.t('common.unknown') if author.empty?

    changes = if version == '0.1.0'
                IsooI18n.t('docs.version_control.first_created')
              else
                IsooI18n.t('docs.version_control.updated')
              end

    [{
      'version' => version,
      'modified' => modified,
      'author' => author,
      'changes' => changes
    }]
  end

  def self.render_version_table(rows, current_version: nil)
    current = current_version.to_s
    heading = IsooI18n.t('docs.version_control.heading')
    html = %(<section class="export-version-control"><h2>#{CGI.escapeHTML(heading)}</h2>)
    html << '<table class="export-table export-version-table"><thead><tr>'
    version_headers.each { |h| html << "<th>#{CGI.escapeHTML(h)}</th>" }
    html << '</tr></thead><tbody>'
    rows.each do |row|
      current_row = current != '' && row['version'] == current
      html << if current_row
                '<tr class="export-version-row--current">'
              else
                '<tr>'
              end
      html << "<td>#{CGI.escapeHTML(row['version'])}</td>"
      html << "<td>#{CGI.escapeHTML(row['modified'])}</td>"
      html << "<td>#{CGI.escapeHTML(row['author'])}</td>"
      html << "<td>#{CGI.escapeHTML(row['changes'])}</td>"
      html << '</tr>'
    end
    html << '</tbody></table></section>'
    html
  end

  def self.version_headers
    [
      IsooI18n.t('docs.version_control.version_col'),
      IsooI18n.t('docs.version_control.modified_col'),
      IsooI18n.t('docs.version_control.author_col'),
      IsooI18n.t('docs.version_control.changes_col')
    ]
  end
  private_class_method :version_headers

  def self.format_version_date(value)
    return '' if value.nil? || value.to_s.strip.empty?

    return value.utc.strftime('%Y-%m-%d') if value.is_a?(Time) || value.is_a?(Date) || value.is_a?(DateTime)

    Time.parse(value.to_s).utc.strftime('%Y-%m-%d')
  rescue ArgumentError, TypeError
    value.to_s.strip[0, 10]
  end
  private_class_method :format_version_date

  def self.strip_leading_version_rows(markdown)
    lines = markdown.to_s.lines
    i = 0
    while i < lines.length
      skip = version_row_line?(lines[i]) ||
             (lines[i].strip.empty? && i + 1 < lines.length && version_row_line?(lines[i + 1]))
      break unless skip

      i += 1
    end
    lines[i..]&.join&.lstrip || ''
  end

  def self.version_control_rows(body)
    VersionControlWriter.sorted_rows(body)
                        .reverse
                        .uniq { |row| row['version'] }
                        .reverse
  end

  def self.version_row_line?(line)
    line.to_s.match?(/\A\|\s*\d+\.\d+\.\d+\s*\|/)
  end
  private_class_method :version_row_line?

  def self.table_legend_html(schema, csv_headers:)
    columns = legend_columns(schema, csv_headers)
    return '' if columns.empty?

    html = +'<section class="export-table-legend"><dl class="export-legend-list">'
    columns.each do |col|
      label = column_label(col)
      description = col['description'].to_s.strip

      html << "<dt>#{CGI.escapeHTML(label)}</dt>"
      if description.empty?
        undocumented = IsooI18n.t('export.legend.undocumented')
        html << %(<dd><span class="export-legend-undocumented">#{CGI.escapeHTML(undocumented)}</span></dd>)
      else
        html << "<dd>#{CGI.escapeHTML(description)}</dd>"
      end
    end
    html << '</dl></section>'
    html
  end

  def self.legend_columns(schema, csv_headers)
    columns_by_key = (schema['columns'] || []).to_h do |col|
      [col['key'].to_s, col]
    end
    headers = Array(csv_headers).compact.map(&:to_s).reject { |h| INTERNAL_COLUMNS.include?(h) }
    headers.filter_map do |key|
      columns_by_key[key] || { 'key' => key, 'label' => key, 'description' => '' }
    end
  end

  def self.column_label(col)
    label = col['label'].to_s.strip
    label.empty? ? col['key'].to_s : label
  end
  private_class_method :legend_columns, :column_label
end
