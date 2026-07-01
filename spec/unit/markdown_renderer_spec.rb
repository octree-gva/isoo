# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe MarkdownRenderer do
  it 'renders markdown images with public paths' do
    html = described_class.to_html('Guide text. ![ISMS Overview](/img/ism_overview.png)')

    expect(html).to include('<img')
    expect(html).to include('src="/img/ism_overview.png"')
    expect(html).to include('alt="ISMS Overview"')
  end

  it 'returns empty string for blank input' do
    expect(described_class.to_html('   ')).to eq('')
  end

  it 'renders list items with inline mailto links as a single li' do
    md = <<~MD
      ### The Rights of Data Subjects

      - SAMPLE Access via [privacy@example.org](mailto:privacy@example.org) within timelines.
    MD
    html = described_class.to_html(md)

    expect(html).to include('<ul>')
    expect(html).to match(
      %r{<li>SAMPLE Access via <a href="mailto:privacy@example\.org">privacy@example\.org</a> within timelines\.</li>}
    )
  end
end
