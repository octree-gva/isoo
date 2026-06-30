# frozen_string_literal: true

namespace :security do
  desc 'Run Brakeman static analysis and bundler-audit CVE check'
  task scan: %i[brakeman bundler_audit]

  desc 'Run Brakeman (Rails/Rack security scanner)'
  task :brakeman do
    sh 'brakeman -q -w2 -f plain'
  end

  desc 'Check gems for known CVEs'
  task :bundler_audit do
    sh 'bundle audit check --update'
  end
end
