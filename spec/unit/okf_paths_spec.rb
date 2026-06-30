# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe OkfPaths do
  it 'resolves okf file paths' do
    expect(described_class.md('context/organisation-overview')).to eq(
      'context/organisation-overview/organisation-overview.md'
    )
    expect(described_class.schema('context/organisation-overview')).to include('.schema.yaml')
  end
end
