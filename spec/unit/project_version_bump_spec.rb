# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ProjectVersionBump do
  it 'starts from default' do
    expect(described_class.next_version(nil, significant: false)).to eq('0.0.1')
  end

  it 'increments patch on minor change' do
    expect(described_class.next_version('0.0.0', significant: false)).to eq('0.0.1')
    expect(described_class.next_version('0.1.3', significant: false)).to eq('0.1.4')
  end

  it 'rolls patch 9 to minor +1 and patch 0' do
    expect(described_class.next_version('0.0.9', significant: false)).to eq('0.1.0')
    expect(described_class.next_version('1.2.9', significant: false)).to eq('1.3.0')
  end

  it 'rolls minor 10 to major +1 on patch overflow' do
    expect(described_class.next_version('0.9.9', significant: false)).to eq('1.0.0')
  end

  it 'increments minor on major change' do
    expect(described_class.next_version('0.0.0', significant: true)).to eq('0.1.0')
    expect(described_class.next_version('0.1.2', significant: true)).to eq('0.2.0')
  end

  it 'rolls minor 10 to major +1 on major change' do
    expect(described_class.next_version('0.9.0', significant: true)).to eq('1.0.0')
  end

  it 'normalizes missing and legacy version values to semver' do
    expect(described_class.normalize_version(nil)).to eq('0.0.0')
    expect(described_class.normalize_version('')).to eq('0.0.0')
    expect(described_class.normalize_version('0.0.2')).to eq('0.0.2')
    expect(described_class.normalize_version(2)).to eq('0.0.2')
    expect(described_class.normalize_version(0.02)).to eq('0.0.2')
  end
end
