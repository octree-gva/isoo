# frozen_string_literal: true

require 'bundler/setup'
require_relative '../../app/app'

namespace :isoo do
  namespace :storage do
    desc 'Check STORAGE_BACKEND (or optional backend name) preconditions'
    task :check, [:backend] do |_t, args|
      backend_name = args[:backend].to_s.strip
      backend_name = StorageBackend.name if backend_name.empty?
      backend = StorageBackend.build(name: backend_name)
      backend.check!
      puts "OK: storage backend #{backend.name} passed preflight"
    rescue StorageBackend::PreconditionError => e
      warn "FAIL: #{e.message}"
      exit 1
    end

    desc 'Migrate project data from current STORAGE_BACKEND to TARGET (e.g. migrate[s3])'
    task :migrate, [:target] do |_t, args|
      target_name = args[:target].to_s.strip.downcase
      if target_name.empty?
        warn 'Usage: rake isoo:storage:migrate[s3]  (local|git|webdav|s3)'
        exit 1
      end

      source_name = StorageBackend.name
      if source_name == target_name
        warn "Source and target are both #{source_name}; nothing to do"
        exit 1
      end

      source = StorageBackend.build(name: source_name)
      target = StorageBackend.build(name: target_name)

      begin
        source.check!
        target.check!
      rescue StorageBackend::PreconditionError => e
        warn "Precondition failed (no data moved): #{e.message}"
        exit 1
      end

      pull = source.pull!
      if pull.is_a?(Hash) && pull[:status] == :error
        warn "Pull from #{source_name} failed: #{pull[:message]}"
        exit 1
      end

      target.flush!("migrate from #{source_name} to #{target_name}")
      puts "Migrated data from #{source_name} to #{target_name}."
      puts "Set STORAGE_BACKEND=#{target_name} and restart the app."
      puts 'Then run: rake isoo:storage:check'
    end
  end
end
