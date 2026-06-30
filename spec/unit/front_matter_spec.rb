# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe FrontMatter do
  it 'parses yaml front matter' do
    text = "---\niso27001:\n  version: 0.1.0\n---\n\n# Body\n"
    meta, body = described_class.parse(text)
    expect(meta.dig('iso27001', 'version')).to eq('0.1.0')
    expect(body).to include('# Body')
  end

  it 'returns empty meta without front matter' do
    meta, body = described_class.parse("# Only body\n")
    expect(meta).to eq({})
    expect(body).to include('Only body')
  end

  it 'dumps front matter' do
    out = described_class.dump({ 'x' => 1 }, 'body')
    expect(out).to start_with("---\n")
    expect(out).to include('body')
  end

  it 'parses description values containing colons' do
    text = "---\ndescription: Meeting Date and Time: 1/1/2021\n---\n\nbody\n"
    meta, = described_class.parse(text)
    expect(meta['description']).to include('Meeting Date')
  end
end
