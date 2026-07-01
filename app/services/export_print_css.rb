# frozen_string_literal: true

class ExportPrintCss
  BASE_PATH = File.expand_path('../../assets/css/export-print.css', __dir__)
  PAGE_MARGIN = '74px 64px 128px 64px'
  PAGE_MARGIN_TOP_IN = 74.0 / 96
  PAGE_MARGIN_RIGHT_IN = 64.0 / 96
  PAGE_MARGIN_BOTTOM_IN = 128.0 / 96
  PAGE_MARGIN_LEFT_IN = 64.0 / 96
  PDF_FONT_SIZE = '11px'
  CHROME_PADDING = '64px'

  def self.chrome_header_footer_style
    "padding: 8px #{CHROME_PADDING};"
  end

  def self.load
    "#{ExportPrintFonts.css}\n#{File.read(BASE_PATH)}"
  end

  def self.pdf_override
    margin = PAGE_MARGIN
    font_size = PDF_FONT_SIZE
    <<~CSS

      @media print {
        @page { margin: #{margin}; }
        @page export-portrait { margin: #{margin}; size: A4 portrait; }
        @page export-landscape { margin: #{margin}; size: A4 landscape; }

        html.export-pdf-root {
          font-size: #{font_size};
        }

        body.export-pdf {
          font-size: #{font_size};
        }

        body.export-pdf .export-cover,
        body.export-pdf .export-toc,
        body.export-pdf .export-section-divider {
          padding-top: 0;
          padding-bottom: 0;
        }

        body.export-pdf .export-doc,
        body.export-pdf .export-table-wrap {
          padding-top: 0;
          padding-bottom: 0;
        }

        body.export-pdf .export-version-control {
          break-inside: auto;
          page-break-inside: auto;
          margin: 0 0 1rem;
        }

        body.export-pdf .export-version-table {
          page: auto;
        }

        body.export-pdf .export-version-table tr {
          break-inside: auto;
          page-break-inside: auto;
        }

        body.export-pdf .export-body ul li {
          break-inside: auto;
          page-break-inside: auto;
          overflow-wrap: anywhere;
          word-break: break-word;
        }
      }
    CSS
  end
end
