# frozen_string_literal: true

namespace :isoo do
  desc 'Lint ERB templates'
  task erb_lint: :environment do
    sh 'bundle exec erb_lint --lint-all'
  end
end
