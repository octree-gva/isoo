# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ExportTagRegistry do
  describe '.tags_for' do
    let(:registry) do
      described_class.new([
                            { 'id' => 'basic', 'scopes' => %w[document] },
                            { 'id' => 'soi', 'scopes' => %w[document asset] },
                            { 'id' => 'asset_only', 'scopes' => %w[asset] }
                          ])
    end

    it 'returns asset-scoped tags for asset category' do
      ids = registry.tags_for('asset').map { |tag| tag['id'] }
      expect(ids).to contain_exactly('soi', 'asset_only')
    end

    it 'returns document and shared tags for document category' do
      ids = registry.tags_for('document').map { |tag| tag['id'] }
      expect(ids).to contain_exactly('basic', 'soi')
    end

    it 'returns union when multiple categories are passed' do
      ids = registry.tags_for('document', 'asset').map { |tag| tag['id'] }
      expect(ids).to contain_exactly('basic', 'soi', 'asset_only')
    end
  end
end
