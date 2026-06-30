# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe AnnexReference do
  let(:resolver) do
    instance_double(
      AnnexReferenceResolver,
      title_for: 'Architectural schema',
      href_for: '#annex-ref-architecture-schema'
    )
  end

  it 'extracts unique annex doc ids in order' do
    text = 'See [ANNEX architecture-schema] and [ANNEX network-diagram], again [ANNEX architecture-schema].'
    expect(described_class.extract(text)).to eq(%w[architecture-schema network-diagram])
    expect(described_class.extract_ordered(text)).to eq(%w[architecture-schema network-diagram])
  end

  it 'rewrites bbcode to markdown links' do
    text = 'Diagram: [ANNEX architecture-schema].'
    expect(described_class.rewrite_markdown(text, resolver: resolver)).to eq(
      'Diagram: [Architectural schema](#annex-ref-architecture-schema).'
    )
  end

  it 'leaves unknown annex references unchanged' do
    allow(resolver).to receive(:title_for).with('missing').and_return(nil)
    text = 'See [ANNEX missing].'
    expect(described_class.rewrite_markdown(text, resolver: resolver)).to eq(text)
  end
end
