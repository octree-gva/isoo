# frozen_string_literal: true

require 'cgi'
require_relative 'isoo_html'
require_relative 'services/markdown_renderer'

module ViewHelpers
  def t(key, **)
    IsooI18n.t(key, **)
  end

  def escape_html(text)
    CGI.escapeHTML(text.to_s)
  end

  def markdown_html(text)
    html = MarkdownRenderer.to_html(text.to_s)
    return '' if html.strip.empty?

    IsooHtml.new(html)
  end

  def doc_header(meta, doc, project_root: @project_root)
    @header_title = doc['title'] || meta['title'] || doc['doc_id']
    @header_description = DocumentDescription.resolve(
      meta, doc, data_root: App::DATA_PATH, project_root: project_root
    )
    @header_version = meta.dig('iso27001', 'version')
    @header_classification = meta.dig('iso27001', 'classification')
    set_back_nav(doc) unless @back_href
  end

  def set_back_nav(doc)
    if doc['form_id']
      form = @manifest.find_form(doc['form_id'])
      @back_href = "/projects/#{@slug}/forms/#{doc['form_id']}"
      @back_label = form&.fetch('title', doc['form_id'])
    elsif doc['kind'] == 'file_annex'
      @back_href = "/projects/#{@slug}/annexes"
      @back_label = t('annexes.folder_label')
    else
      @back_href = "/projects/#{@slug}"
      @back_label = t('a11y.back_to_project', name: @manifest&.name || @slug)
    end
  end

  def json_attr(value)
    ::JsonAttr.encode(value)
  end

  def text_form_draft_baseline(fields, document_title: nil, sections: nil)
    # document_title first — matches DOM order in text.erb (JSON key order matters).
    baseline = {}
    baseline['document_title'] = document_title.to_s if document_title
    section_by_key = Array(sections).each_with_object({}) do |sec, acc|
      acc[sec['key'].to_s] = sec
    end
    fields.each do |key, value|
      k = key.to_s
      sec = section_by_key[k]
      baseline[k] = if sec && (sec['field_type'] || 'textarea') == 'switch'
                      ::TableSwitch.on?(value, sec) ? '1' : '0'
                    else
                      value.to_s
                    end
    end
    baseline
  end

  def table_form_draft_baseline(rows, columns: nil)
    column_list = Array(columns)
    mapped = rows.each_with_object({}) do |row, acc|
      row_id = row['_row_id']
      next if row_id.to_s.empty?

      acc[row_id] = if column_list.empty?
                      row.except('_row_id', '_deleted_at')
                         .reject { |k, _| DocumentOwner.owner_key?(k) }
                         .transform_keys(&:to_s)
                         .transform_values { |v| draft_switch_value(v) }
                    else
                      column_list.each_with_object({}) do |col, cells|
                        key = col['key'].to_s
                        value = row[key]
                        cells[key] = case col['type']
                                     when 'switch'
                                       ::TableSwitch.on?(value, col) ? '1' : '0'
                                     when 'checkbox'
                                       value.to_s == '1' ? '1' : '0'
                                     else
                                       value.to_s
                                     end
                      end
                    end
    end
    { 'rows' => mapped }
  end

  def draft_switch_value(value)
    str = value.to_s.strip
    return str unless %w[1 true yes on 0 false no off].include?(str.downcase)

    ::TableSwitch.on?(str) ? '1' : '0'
  end

  # Marks a content control for leave-guard dirty tracking (see public/js/form-draft.js).
  def draft_track_attr
    ' data-draft-track data-dirty="false"'
  end

  def table_data_columns(schema)
    DocumentOwner.data_columns(schema)
  end

  def document_owner_from_rows(rows, meta = nil)
    DocumentOwner.from_document(meta: meta, rows: rows)
  end

  def table_switch_on?(value, col = nil)
    ::TableSwitch.on?(value, col)
  end

  def dashboard_doc_icon(kind)
    case kind.to_s
    when 'table' then 'ri-table-line'
    when 'text' then 'ri-file-text-line'
    else 'ri-file-line'
    end
  end

  def dashboard_export_tag_labels(tag_ids)
    registry = @export_tag_registry || ExportTagRegistry.empty
    Array(tag_ids).map { |id| registry.label_for(id) }.reject(&:empty?)
  end
end
