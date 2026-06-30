# frozen_string_literal: true

require_relative '../spec_helper'
require_relative '../../app/session_idle'

RSpec.describe SessionIdle do
  it 'defaults to a two hour idle timeout' do
    expect(described_class.timeout_seconds).to eq(7200)
  end

  it 'detects expired sessions' do
    session = {
      'user' => { 'email' => 'user@example.com' },
      'last_activity_at' => Time.now.to_i - 7201
    }

    expect(described_class.expired?(session)).to be(true)
  end

  it 'does not expire active sessions' do
    session = {
      'user' => { 'email' => 'user@example.com' },
      'last_activity_at' => Time.now.to_i - 60
    }

    expect(described_class.expired?(session)).to be(false)
  end
end
