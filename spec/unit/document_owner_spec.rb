# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe DocumentOwner do
  it 'validates owner name and email' do
    expect do
      described_class.validate!('owner_name' => 'Hadrien', 'owner_email' => 'hadrien@octree.ch')
    end.not_to raise_error

    expect do
      described_class.validate!('owner_name' => '', 'owner_email' => 'a@b.co')
    end.to raise_error(ArgumentError, /owner name/i)

    expect do
      described_class.validate!('owner_name' => 'Hadrien', 'owner_email' => 'bad')
    end.to raise_error(ArgumentError, /email/i)
  end

  it 'propagates owner values to every row' do
    rows = [{ 'standard' => 'GDPR', '_row_id' => '1' }, { 'standard' => 'ISO', '_row_id' => '2' }]
    owner = { 'owner_name' => 'Hadrien', 'owner_email' => 'hadrien@octree.ch' }
    updated = described_class.propagate_to_rows(rows, owner)
    expect(updated).to all(include('owner_name' => 'Hadrien', 'owner_email' => 'hadrien@octree.ch'))
  end

  it 'formats export footer line' do
    line = described_class.export_line('owner_name' => 'Hadrien', 'owner_email' => 'hadrien@octree.ch')
    expect(line).to include('Hadrien')
    expect(line).to include('<hadrien@octree.ch>')
  end

  it 'reads owner from the first populated table row' do
    rows = [
      { 'owner_name' => '', 'owner_email' => '' },
      { 'owner_name' => 'Alex', 'owner_email' => 'alex@example.com' }
    ]
    expect(described_class.from_rows(rows)).to eq(
      'owner_name' => 'Alex',
      'owner_email' => 'alex@example.com'
    )
  end
end
