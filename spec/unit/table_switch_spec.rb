# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/table_switch'

RSpec.describe TableSwitch do
  it 'reads explicit values' do
    expect(described_class.on?('1')).to be true
    expect(described_class.on?('0')).to be false
  end

  it 'uses column default when value is blank' do
    expect(described_class.on?('', { 'default' => true })).to be true
    expect(described_class.on?('', { 'default' => false })).to be false
  end
end
