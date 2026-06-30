# frozen_string_literal: true

require 'json'
require 'yaml'

module IsooI18n
  module_function

  def locale
    @locale ||= ENV.fetch('ISOO_LOCALE', 'en')
  end

  def translations
    @translations ||= load_translations
  end

  def t(key, **opts)
    parts = key.to_s.split('.')
    node = translations.dig(locale, *parts) || translations.dig('en', *parts) || key.to_s
    return node unless node.is_a?(String) && opts.any?

    node % opts
  rescue KeyError
    node
  end

  def js_payload
    translations.fetch(locale, translations.fetch('en', {}))
  end

  def to_js
    js_payload.to_json
  end

  def load_translations
    Dir[File.expand_path('../config/locales/*.yml', __dir__)].each_with_object({}) do |path, acc|
      acc.merge!(YAML.safe_load_file(path) || {})
    end
  end
  private_class_method :load_translations
end
