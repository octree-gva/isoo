# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe IsooI18n do
  it 'translates keys' do
    expect(described_class.t('actions.save')).to eq('Save')
  end

  it 'interpolates values' do
    expect(described_class.t('docs.meta.version', version: '0.2.0')).to include('0.2.0')
  end

  it 'exports locale hash as JSON for the browser' do
    payload = described_class.js_payload
    expect(payload).to be_a(Hash)
    expect(payload.dig('actions', 'save')).to eq('Save')
    expect(described_class.to_js).to eq(payload.to_json)
  end
end
