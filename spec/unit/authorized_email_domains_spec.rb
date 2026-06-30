# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe AuthorizedEmailDomains do
  around do |example|
    old = ENV.fetch('AUTH_ALLOWED_EMAIL_DOMAINS', nil)
    example.run
  ensure
    if old
      ENV['AUTH_ALLOWED_EMAIL_DOMAINS'] = old
    else
      ENV.delete('AUTH_ALLOWED_EMAIL_DOMAINS')
    end
  end

  it 'allows any email when no domains are configured' do
    ENV.delete('AUTH_ALLOWED_EMAIL_DOMAINS')
    expect(described_class.allowed?('user@anywhere.test')).to be(true)
  end

  it 'allows emails from configured domains' do
    ENV['AUTH_ALLOWED_EMAIL_DOMAINS'] = 'voca.city, Example.COM '
    expect(described_class.allowed?('dpo@voca.city')).to be(true)
    expect(described_class.allowed?('ceo@example.com')).to be(true)
  end

  it 'rejects emails from other domains' do
    ENV['AUTH_ALLOWED_EMAIL_DOMAINS'] = 'voca.city'
    expect(described_class.allowed?('user@gmail.com')).to be(false)
    expect(described_class.allowed?('')).to be(false)
    expect(described_class.allowed?(nil)).to be(false)
  end
end
