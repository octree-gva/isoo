# frozen_string_literal: true

require_relative '../../spec_helper'

RSpec.describe Cache::NullStore do
  subject(:store) { described_class.new }

  it 'is disabled' do
    expect(store.enabled?).to be false
  end

  it 'always executes the block' do
    calls = 0
    2.times { store.fetch('key', scope: 'project:demo') { calls += 1 } }
    expect(calls).to eq(2)
  end

  it 'ignores bump and delete' do
    expect(store.bump('project:demo')).to be_nil
    expect(store.delete('key', scope: 'project:demo')).to be_nil
  end
end
