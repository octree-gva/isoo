# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ExportPdfRenderer do
  it 'renders HTML to PDF via FerrumPdf with Chrome header and footer templates' do
    html = '<html><body class="export-pdf"><h1>Export</h1></body></html>'
    pdf_bytes = +'%PDF-1.4 test'
    export_date = '2026-06-28'

    expect(FerrumPdf).to receive(:render_pdf) do |**kwargs|
      expect(kwargs[:html]).to eq(html)
      expect(kwargs[:display_url]).to eq('http://example.org/projects/demo/export?format=html')
      options = kwargs[:pdf_options]
      expect(options[:display_header_footer]).to be(true)
      expect(options[:header_template]).to include(
        'Demo Project', '6mm', 'padding: 8px 64px'
      )
      expect(options[:header_template]).not_to include('height:100%')
      expect(options[:margin_top]).to be_within(0.001).of(74.0 / 96)
      expect(options[:margin_bottom]).to be_within(0.001).of(128.0 / 96)
      expect(options[:margin_left]).to be_within(0.001).of(64.0 / 96)
      expect(options[:margin_right]).to be_within(0.001).of(64.0 / 96)
      expect(options[:footer_template]).to include(
        export_date, 'pageNumber', 'totalPages', 'Demo Project',
        'padding: 8px 64px',
        'grid-template-columns:1fr 1fr 1fr',
        'text-align:left', 'text-align:center', 'text-align:right'
      )
      expect(options[:footer_template]).not_to include('Page ')
      pdf_bytes
    end

    result = described_class.render(
      html,
      display_url: 'http://example.org/projects/demo/export?format=html',
      title: 'Demo Project',
      logo_data_uri: 'data:image/png;base64,abc',
      export_date: export_date
    )

    expect(result).to eq(pdf_bytes)
  end
end
