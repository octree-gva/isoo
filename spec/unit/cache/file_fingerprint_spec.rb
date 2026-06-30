# frozen_string_literal: true

require 'tmpdir'
require_relative '../../spec_helper'

RSpec.describe Cache::FileFingerprint do
  it 'returns missing for absent files' do
    expect(described_class.call('/tmp/does-not-exist-isoo')).to eq('missing')
  end

  it 'changes when file content changes' do
    Dir.mktmpdir do |tmp|
      path = File.join(tmp, 'doc.md')
      File.write(path, 'short')
      first = described_class.call(path)
      File.write(path, 'much longer content')
      second = described_class.call(path)
      expect(second).not_to eq(first)
    end
  end
end
