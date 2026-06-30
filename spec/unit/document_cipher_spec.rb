# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe DocumentCipher do
  it 'encrypts and decrypts' do
    plain = 'confidential body'
    blob = described_class.encrypt(plain)
    expect(described_class.decrypt(blob)).to eq(plain)
  end

  it 'detects confidential classification' do
    expect(described_class.confidential?('Confidential')).to be true
    expect(described_class.confidential?('Public')).to be false
  end
end
