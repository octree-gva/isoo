# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ExportPrintCss do
  describe '.pdf_override' do
    subject(:css) { described_class.pdf_override }

    it 'sets page margins to 74px 64px 128px 64px on all page types' do
      expect(css).to include('@page { margin: 74px 64px 128px 64px; }')
      expect(css).to include('@page export-portrait { margin: 74px 64px 128px 64px;')
      expect(css).to include('@page export-landscape { margin: 74px 64px 128px 64px;')
    end

    it 'sets PDF body font size to 11px' do
      expect(css).to include('html.export-pdf-root {')
      expect(css).to include('font-size: 11px;')
    end

    it 'keeps version control tables visible in PDF output' do
      expect(css).to include('body.export-pdf .export-version-control')
      expect(css).to include('body.export-pdf .export-version-table')
    end

    it 'allows list items to wrap without orphaning the em dash marker' do
      expect(css).to include('body.export-pdf .export-body ul li')
      expect(css).to include('overflow-wrap: anywhere')
      expect(css).to include('word-break: break-word')
    end
  end

  describe '.chrome_header_footer_style' do
    it 'sets padding for Chrome header and footer templates' do
      expect(described_class.chrome_header_footer_style).to eq('padding: 8px 64px;')
    end
  end
end
