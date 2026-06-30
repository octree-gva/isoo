# frozen_string_literal: true

require 'ferrum_pdf'

FerrumPdf.configure do |config|
  next unless ENV['CHROME_NO_SANDBOX'] == '1' || File.exist?('/.dockerenv')

  config.browser_options = {
    'no-sandbox' => true,
    'disable-dev-shm-usage' => true
  }
end
