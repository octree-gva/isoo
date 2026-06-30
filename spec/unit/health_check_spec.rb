# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe HealthCheck do
  describe '.live' do
    it 'reports ok' do
      expect(described_class.live).to eq(status: 'ok')
    end
  end

  describe '.ready' do
    it 'reports ok when data and templates exist' do
      body = described_class.ready
      expect(body[:status]).to eq('ok')
      expect(body[:checks]['data_path']).to be true
      expect(body[:checks]['templates']).to be true
    end
  end
end
