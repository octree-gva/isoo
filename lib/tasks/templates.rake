# frozen_string_literal: true

require 'bundler/setup'
require_relative '../../app/app'

namespace :isoo do
  desc 'Validate OKF template bundle under data/templates (schemas, manifest, table CSV headers)'
  task validate_templates: :environment do
    template_id = ENV.fetch('TEMPLATE_ID', 'voca')
    bundle = File.join(App::TEMPLATES_PATH, template_id)
    validator = TemplateValidator.new(bundle)
    validator.validate
    if validator.errors.any?
      validator.errors.each { |err| warn err }
      abort "#{validator.errors.size} template error(s)"
    end

    count = YAML.safe_load_file(File.join(bundle, 'manifest.yaml')).fetch('documents', []).size
    puts "OK #{count} documents in #{bundle}"
  end

  desc 'Write export_tags into template schemas from assignment rules'
  task sync_export_tags: :environment do
    template_id = ENV.fetch('TEMPLATE_ID', 'voca')
    bundle = File.join(App::TEMPLATES_PATH, template_id)
    updated = ExportTagAssigner.new(bundle).sync!
    puts "Updated export_tags on #{updated} schema(s) in #{bundle}"
  end
end
