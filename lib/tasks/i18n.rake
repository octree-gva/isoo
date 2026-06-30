# frozen_string_literal: true

namespace :i18n do
  desc 'Report missing translations'
  task missing: :environment do
    abort unless system('bundle', 'exec', 'i18n-tasks', 'missing')
  end

  desc 'Report unused translations'
  task unused: :environment do
    abort unless system('bundle', 'exec', 'i18n-tasks', 'unused')
  end

  desc 'Fail CI when translations are missing or inconsistent'
  task check: :environment do
    steps = %w[
      missing
      check-consistent-interpolations
    ]
    steps.each do |step|
      puts "== i18n-tasks #{step} =="
      system('bundle', 'exec', 'i18n-tasks', step) || abort("i18n-tasks #{step} failed")
    end
  end
end

task :environment do
  # i18n-tasks reads YAML from config/locales; no app boot required.
end
