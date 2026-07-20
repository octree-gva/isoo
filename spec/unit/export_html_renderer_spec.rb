# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ExportHtmlRenderer do
  it 'renders document bodies, version control, logo, and tables as HTML' do
    html = described_class.render(
      title: 'Demo',
      generated_at: '2026-06-28 12:00 UTC',
      entries: [{
        'doc_id' => 'organisation-overview',
        'title' => 'Organisation Overview',
        'group' => 'Context',
        'version' => '0.1.0',
        'classification' => 'Confidential',
        'body_html' => '<p><strong>About us</strong></p>',
        'table_html' => '<table class="export-table"><tr><td>A</td></tr></table>',
        'version_control_html' => '<section class="export-version-control"><h2>Document Version Control</h2></section>',
        'annex_assets_html' => '',
        'has_data_table' => true
      }],
      print_css: 'body { color: #000; }',
      logo_data_uri: 'data:image/png;base64,abc'
    )

    expect(html).to include('data-export="isoo-html-v3"')
    expect(html).to include('<p><strong>About us</strong></p>')
    expect(html).to include('export-version-control')
    expect(html).to include('export-print-header__logo')
    expect(html).to include('export-doc--has-data')
    expect(html).to include('export-print-footer__page')
    expect(html).to include('export-print-footer__date')
    expect(html).not_to include('&lt;p&gt;', 'export-cover-note', 'single HTML file')
  end

  it 'omits CSS print chrome and adds export-pdf body class for PDF rendering' do
    html = described_class.render(
      title: 'Demo',
      generated_at: '2026-06-28 12:00 UTC',
      entries: [],
      print_css: 'body { color: #000; }',
      pdf_export: true,
      export_date: '2026-06-28'
    )

    expect(html).to include(
      '<body class="export-pdf">',
      'class="export-pdf-root"',
      '@page { margin: 74px 64px 128px 64px; }',
      'html.export-pdf-root',
      'font-size: 11px;'
    )
    expect(html).not_to include('<div class="export-print-header"')
  end

  it 'renders owner maintained line on cover and ownership section for a single document' do
    html = described_class.render(
      title: 'Demo — Agenda 1',
      generated_at: '2026-07-20 16:38 UTC',
      entries: [{
        'doc_id' => 'agenda-1',
        'title' => 'Agenda 1',
        'group' => 'Meetings',
        'version' => '0.1.0',
        'body_html' => '<p>Notes</p>',
        'table_html' => '',
        'version_control_html' => '',
        'annex_assets_html' => '',
        'has_data_table' => false,
        'owner_maintained_line' => 'This documented information is owned by Hadrien Froger <hadrien@octree.ch>.',
        'owner_ownership_heading' => 'Document Ownership',
        'owner_ownership_body' =>
          'Hadrien Froger <hadrien@octree.ch> is the document owner and is accountable for the suitability and adequacy of this documented information, including its review, approval, and control of changes (ISO/IEC 27001:2022 Clause 7.5).'
      }],
      print_css: 'body { color: #000; }'
    )

    expect(html).to include('This document contains confidential information.')
    expect(html).to include('This documented information is owned by Hadrien Froger')
    expect(html).to include('Do not share it outside your organization.')
    expect(html).to include('Document Ownership')
    expect(html).to include('suitability and adequacy')
    expect(html).to include('export-doc-ownership')
  end

  it 'renders full-page section dividers before annex and form documents' do
    html = described_class.render(
      title: 'Demo',
      generated_at: '2026-06-28 12:00 UTC',
      entries: [
        {
          'doc_id' => 'policy',
          'title' => 'Policy',
          'group' => 'Policies',
          'export_tier' => 'main',
          'body_html' => '<p>Policy text</p>',
          'table_html' => '',
          'version_control_html' => '',
          'annex_assets_html' => '',
          'has_data_table' => false
        },
        {
          'doc_id' => 'diagram',
          'title' => 'Diagram',
          'group' => 'Annexes',
          'export_tier' => 'annex',
          'body_html' => '<p>Annex text</p>',
          'table_html' => '',
          'version_control_html' => '',
          'annex_assets_html' => '',
          'has_data_table' => false
        },
        {
          'doc_id' => 'audit-1',
          'title' => 'Audit 1',
          'group' => 'Audit',
          'export_tier' => 'form',
          'body_html' => '<p>Audit text</p>',
          'table_html' => '',
          'version_control_html' => '',
          'annex_assets_html' => '',
          'has_data_table' => false
        }
      ],
      print_css: 'body { color: #000; }'
    )

    expect(html).to include('<section class="export-section-divider" aria-label="Annex files">')
    expect(html).to include('<h1>Annex files</h1>')
    expect(html).to include('<section class="export-section-divider" aria-label="Annex documents">')
    expect(html).to include('<h1>Annex documents</h1>')
    expect(html).to include('Meetings, Audits, Plans, Form Submissions')
    expect(html.index('Annex files')).to be < html.index('id="diagram"')
    expect(html.index('Annex documents')).to be < html.index('id="audit-1"')
  end
end
