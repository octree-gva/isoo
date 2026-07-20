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

  def seed_test_annexes!(slug)
    DemoSeeder.new(data_root: App::DATA_PATH).seed_annexes(slug: slug, author: 'spec@isoo.local')
  end
end
