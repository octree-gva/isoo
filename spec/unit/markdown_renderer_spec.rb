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
end
