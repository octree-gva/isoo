# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/json_attr'

RSpec.describe JsonAttr do
  it 'escapes JSON for HTML attributes' do
    expect(described_class.encode({ 'a' => '1"2' })).to eq('{&quot;a&quot;:&quot;1\\&quot;2&quot;}')
  end
end
