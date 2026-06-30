# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe SemverBump do
  it 'bumps minor' do
    expect(described_class.next_version('0.1.0', significant: false)).to eq('0.2.0')
  end

  it 'bumps major below threshold' do
    expect(described_class.next_version('0.1.0', significant: true)).to eq('1.0.0')
  end

  it 'graduates at 0.11.0' do
    expect(described_class.next_version('0.11.0', significant: true)).to eq('1.0.0')
  end

  it 'keeps 0.10.10 major bump normal' do
    expect(described_class.next_version('0.10.10', significant: true)).to eq('1.0.0')
  end
end
