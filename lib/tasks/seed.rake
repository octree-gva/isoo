# frozen_string_literal: true

require 'bundler/setup'
require 'fileutils'
require_relative '../../app/app'

task :environment do
  # App and services loaded via app.rb
end

namespace :isoo do
  desc 'Create demo project with sample documents and table rows for presentations'
  task seed: :environment do
    data = App::DATA_PATH
    git = GitService.new(data)
    creator = ProjectCreator.new(data_root: data, template_id: Container.template_id, git: git)
    slug = ENV.fetch('SEED_PROJECT_SLUG', 'demo')
    name = ENV.fetch('SEED_PROJECT_NAME', 'Acme Open Source')
    author = ENV.fetch('SEED_AUTHOR', 'seed@isoo.local')
    dest = File.join(data, 'projects', slug)

    if ENV['SEED_RESET'] == '1' && File.directory?(dest)
      FileUtils.rm_rf(dest)
      puts "Removed existing project #{slug}"
    end

    removed = creator.prune_except!(keep_slug: slug)
    removed.each { |other| puts "Removed project #{other}" }

    unless File.directory?(dest)
      creator.create(name: name, slug: slug, author: author)
      puts "Created project #{slug}"
    end

    result = DemoSeeder.new(data_root: data, git: git).populate(
      slug: slug,
      author: author,
      force: ENV['SEED_FORCE'] == '1'
    )

    case result
    when :populated
      puts 'Populated demo content (text docs + table rows)'
    when :skipped
      puts 'Demo content already present (set SEED_FORCE=1 to re-populate)'
    end

    puts ''
    puts 'Demo tour:'
    puts "  http://localhost:9292/projects/#{slug}"
    puts "  http://localhost:9292/projects/#{slug}/docs/organisation-overview"
    puts "  http://localhost:9292/projects/#{slug}/docs/legal-and-contractual-requirements-register"
    puts "  http://localhost:9292/projects/#{slug}/docs/isms-risk-register"
    puts "  http://localhost:9292/projects/#{slug}/docs/physical-and-virtual-assets-register"
  end
end

task default: 'isoo:seed'
