# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe Container do
  it 'exposes shared services' do
    expect(described_class.git).to be_a(GitService)
    expect(described_class.projects).to be_a(ProjectCreator)
    expect(described_class.cache).to be_a(Cache::NullStore)
  end
end
