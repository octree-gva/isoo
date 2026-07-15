# frozen_string_literal: true

require 'cgi'

require_relative '../i18n'

class ExportHtmlRenderer
  def self.render(title:, generated_at:, entries:, print_css:, logo_data_uri: nil, pdf_export: false,
                  export_date: nil)
    new(
      title: title,
      generated_at: generated_at,
      entries: entries,
      print_css: print_css,
      logo_data_uri: logo_data_uri,
      pdf_export: pdf_export,
      export_date: export_date
    ).render
  end

  def initialize(title:, generated_at:, entries:, print_css:, logo_data_uri: nil, pdf_export: false,
                 export_date: nil)
    @title = title.to_s
    @generated_at = generated_at.to_s
    @entries = entries
    @print_css = print_css.to_s
    @logo_data_uri = logo_data_uri.to_s
    @pdf_export = pdf_export
    @export_date = export_date.to_s.strip
    @export_date = Time.now.utc.strftime('%Y-%m-%d') if @export_date.empty?
    @running_owner_line = @entries.size == 1 ? @entries.first['owner_footer_line'].to_s.strip : ''
  end

  def render
    body_class = @pdf_export ? ' class="export-pdf"' : ''
    html_class = @pdf_export ? ' class="export-pdf-root"' : ''
    pdf_css = @pdf_export ? ExportPrintCss.pdf_override : ''
    <<~HTML
      <!DOCTYPE html>
      <html lang="en" data-export="isoo-html-v3"#{html_class}>
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>#{esc(IsooI18n.t('export.page_title', title: @title, date: @export_date))}</title>
        <style>#{@print_css}#{pdf_css}</style>
      </head>
      <body#{body_class}>
        #{print_metadatas unless @pdf_export}
        #{cover}
        #{table_of_contents}
        #{documents}
      </body>
      </html>
    HTML
  end

  private

  def esc(text)
    CGI.escapeHTML(text.to_s)
  end

  def print_metadatas
    logo = if @logo_data_uri.empty?
             ''
           else
             %(<img class="export-print-header__logo" src="#{@logo_data_uri}" ) +
               %(alt="#{esc(IsooI18n.t('export.logo_alt'))}">)
           end

    <<~HTML
      <div class="export-print-header" aria-hidden="true">
        <strong class="export-print-header__title">#{esc(@title)}</strong>
        #{logo}
      </div>
      <div class="export-print-footer" aria-hidden="true">
        <span class="export-print-footer__title">#{esc(running_footer_left)}</span>
        <span class="export-print-footer__date">#{esc(@export_date)}</span>
        <span class="export-print-footer__page"></span>
      </div>
    HTML
  end

  def running_footer_left
    @running_owner_line.empty? ? @title : @running_owner_line
  end

  def cover
    <<~HTML
      <section class="export-cover">
        <h1>#{esc(@title)}</h1>
        <p>#{esc(IsooI18n.t('export.cover.exported_on', at: @generated_at))}</p>
        <p>
          #{esc(IsooI18n.t('export.cover.confidential_line1'))}<br />
          <strong>#{esc(IsooI18n.t('export.cover.confidential_line2'))}</strong>
        </p>
      </section>
    HTML
  end

  def table_of_contents
    return '' if @entries.empty?

    items = @entries.map do |entry|
      doc_id = esc(entry['doc_id'])
      <<~HTML.strip
        <li>
          <a href="##{doc_id}">#{esc(entry['title'])}</a>
          <span class="export-toc-group-label">#{esc(entry['group'])}</span>
        </li>
      HTML
    end.join("\n      ")

    <<~HTML
      <nav class="export-toc" aria-labelledby="export-toc-heading">
        <h2 id="export-toc-heading">#{esc(IsooI18n.t('export.toc.heading'))}</h2>
        <p class="export-toc-summary">#{esc(IsooI18n.t('export.toc.summary', count: @entries.size))}</p>
        <ol class="export-toc-list">
          #{items}
        </ol>
      </nav>
    HTML
  end

  def documents
    parts = []
    seen_tiers = {}

    @entries.each do |entry|
      tier = entry['export_tier'].to_s
      unless seen_tiers[tier]
        parts << section_divider_annex_files if tier == 'annex'
        parts << section_divider_annex_documents if tier == 'form'
        seen_tiers[tier] = true
      end
      parts << document(entry)
    end

    <<~HTML
      <main class="export-main">
        #{parts.join("\n")}
      </main>
    HTML
  end

  def section_divider_annex_files
    section_divider(IsooI18n.t('export.section.annex_files'))
  end

  def section_divider_annex_documents
    section_divider(IsooI18n.t('export.section.annex_documents'),
                    subtitle: IsooI18n.t('export.section.annex_documents_subtitle'))
  end

  def section_divider(title, subtitle: nil)
    subtitle_html = if subtitle.to_s.strip.empty?
                      ''
                    else
                      %(<p class="export-section-divider__subtitle">#{esc(subtitle)}</p>)
                    end

    <<~HTML
      <section class="export-section-divider" aria-label="#{esc(title)}">
        <h1>#{esc(title)}</h1>
        #{subtitle_html}
      </section>
    HTML
  end

  def document(entry)
    doc_id = esc(entry['doc_id'])
    doc_class = entry['has_data_table'] ? 'export-doc export-doc--has-data' : 'export-doc'

    meta = +''
    meta << "<span>#{esc(entry['group'])}</span>" if entry['group']
    meta << "<span>#{esc(IsooI18n.t('export.document.version', version: entry['version']))}</span>" if entry['version']
    meta << "<span>#{esc(entry['classification'])}</span>" if entry['classification']

    version_html = entry['version_control_html'].to_s.strip
    body = entry['body_html'].to_s.strip
    body_html = body.empty? ? '' : %(<div class="export-body">#{body}</div>)

    table = entry['table_html'].to_s.strip
    legend = entry['table_legend_html'].to_s.strip
    table_html = if table.empty?
                   ''
                 else
                   <<~HTML
                     <div class="export-table-wrap">
                       <h3>#{esc(IsooI18n.t('export.document.data_heading'))}</h3>
                       #{legend}
                       #{table}
                     </div>
                   HTML
                 end

    annex_html = entry['annex_assets_html'].to_s.strip
    owner_footer = entry['owner_footer_line'].to_s.strip
    owner_html = if owner_footer.empty?
                   ''
                 else
                   %(<footer class="export-doc-owner">#{esc(owner_footer)}</footer>)
                 end

    <<~HTML
      <article class="#{doc_class}" id="#{doc_id}">
        <header class="export-doc-header">
          <h1>#{esc(entry['title'])}</h1>
          <div class="export-doc-meta">
            #{meta}
          </div>
        </header>
        #{version_html}
        #{body_html}
        #{table_html}
        #{annex_html}
        #{owner_html}
      </article>
    HTML
  end
end
