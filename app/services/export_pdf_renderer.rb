# frozen_string_literal: true

require 'cgi'
require_relative '../../config/ferrum_pdf'
require_relative 'export_print_css'
require_relative '../i18n'

class ExportPdfRenderer
  PDF_OPTIONS = {
    print_background: true,
    format: :A4,
    margin_top: ExportPrintCss::PAGE_MARGIN_TOP_IN,
    margin_bottom: ExportPrintCss::PAGE_MARGIN_BOTTOM_IN,
    margin_left: ExportPrintCss::PAGE_MARGIN_LEFT_IN,
    margin_right: ExportPrintCss::PAGE_MARGIN_RIGHT_IN,
    display_header_footer: true
  }.freeze

  HEADER_LOGO_HEIGHT = '6mm'

  def self.render(html, display_url:, title:, logo_data_uri: '', export_date: nil, owner_line: nil)
    export_date = export_date.to_s.strip
    export_date = Time.now.utc.strftime('%Y-%m-%d') if export_date.empty?
    owner_line = owner_line.to_s.strip

    pdf_options = PDF_OPTIONS.merge(
      header_template: header_template(title: title, logo_data_uri: logo_data_uri),
      footer_template: footer_template(title: title, export_date: export_date, owner_line: owner_line)
    )

    FerrumPdf.render_pdf(
      html: html,
      display_url: display_url,
      pdf_options: pdf_options
    )
  end

  def self.header_template(title:, logo_data_uri:)
    chrome_padding = ExportPrintCss.chrome_header_footer_style
    logo_html = if logo_data_uri.to_s.strip.empty?
                  ''
                else
                  logo_style = "height:#{HEADER_LOGO_HEIGHT};width:auto;object-fit:contain;flex-shrink:0;display:block;"
                  %(<img src="#{logo_data_uri}" alt="#{esc(IsooI18n.t('export.logo_alt'))}" style="#{logo_style}">)
                end

    <<~HTML
      <div style="font-size:8px;line-height:1.2;font-family:'IBM Plex Sans',sans-serif;width:100%;#{chrome_padding};box-sizing:border-box;display:flex;justify-content:space-between;align-items:center;gap:8px;border-bottom:1px solid #ccc;color:#555;">
        <span style="font-weight:600;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;flex:1;min-width:0;">#{esc(title)}</span>
        #{logo_html}
      </div>
    HTML
  end

  def self.footer_template(title:, export_date:, owner_line: nil)
    chrome_padding = ExportPrintCss.chrome_header_footer_style
    left = owner_line.to_s.strip
    left = title if left.empty?
    <<~HTML
      <div style="font-size:8px;line-height:1.2;font-family:'IBM Plex Sans',sans-serif;width:100%;#{chrome_padding};box-sizing:border-box;display:grid;grid-template-columns:1fr 1fr 1fr;align-items:center;border-top:1px solid #ccc;color:#555;">
        <span style="text-align:left;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;">#{esc(left)}</span>
        <span style="text-align:center;white-space:nowrap;">#{esc(export_date)}</span>
        <span style="text-align:right;white-space:nowrap;"><span class="pageNumber"></span>/<span class="totalPages"></span></span>
      </div>
    HTML
  end

  def self.esc(text)
    CGI.escapeHTML(text.to_s)
  end
  private_class_method :esc
end
