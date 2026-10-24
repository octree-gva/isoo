# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe McpAccessStore do
  around do |example|
    original = ENV.fetch('ENCRYPTION_SECRET', nil)
    ENV['ENCRYPTION_SECRET'] = 'test-encryption-secret-for-specs-only-32b'
    example.run
  ensure
    if original.nil?
      ENV.delete('ENCRYPTION_SECRET')
    else
      ENV['ENCRYPTION_SECRET'] = original
    end
  end

  it 'creates hashed tokens and authenticates active ones' do
    Dir.mktmpdir do |tmp|
      store = described_class.new(tmp)
      access, token = store.create!(name: 'Open WebUI', audience: 'soi', mode: 'read')

      expect(token).to start_with('isoo_mcp_')
      expect(File.read(File.join(tmp, 'mcp_accesses.json'))).not_to include(token)
      expect(store.authenticate(token).id).to eq(access.id)
      expect(store.authenticate('wrong')).to be_nil

      store.revoke!(access.id)
      expect(store.authenticate(token)).to be_nil
    end
  end

  it 'rejects authentication when MCP is disabled' do
    Dir.mktmpdir do |tmp|
      store = described_class.new(tmp)
      _access, token = store.create!(name: 'Open WebUI', audience: 'full', mode: 'read')
      expect(store.enabled?).to be(true)

      store.enabled = false
      expect(store.enabled?).to be(false)
      expect(store.authenticate(token)).to be_nil

      store.enabled = true
      expect(store.authenticate(token)).not_to be_nil
    end
  end
end
