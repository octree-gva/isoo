# frozen_string_literal: true

require 'cgi'
require_relative 'services/markdown_renderer'

class IsooHtml < String
  def html_safe?
    true
  end
end

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
