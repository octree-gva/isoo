# frozen_string_literal: true

require 'securerandom'

module ProjectHelpers
  def create_test_project!(name: 'Test', slug: nil)
    slug ||= "test-#{SecureRandom.hex(3)}"
    post '/projects', name: name, slug: slug
    slug
  end

  def owner_params
    { owner_name: 'Test Owner', owner_email: 'owner@example.com' }
  end
end
