# frozen_string_literal: true

require 'deepl'

class DeepLTranslator
  def self.configured?
    !ENV.fetch('DEEPL_API_KEY', '').to_s.empty?
  end

  def self.translate(text, context:, target: 'FR')
    str = text.to_s
    return str unless configured?
    return str if str.strip.empty?

    ensure_auth!
    DeepL.translate(str, nil, target, context: context.to_s).text
  end

  def self.ensure_auth!
    DeepL.configure { |config| config.auth_key = ENV.fetch('DEEPL_API_KEY', nil) }
  end

  def self.context_for(doc:, meta:, project_name:)
    lines = []
    lines << "project: #{project_name}" unless project_name.to_s.strip.empty?
    lines << "doc_id: #{doc['doc_id']}" unless doc['doc_id'].to_s.strip.empty?
    lines << "title: #{doc['title']}" unless doc['title'].to_s.strip.empty?
    classification = meta.dig('iso27001', 'classification')
    lines << "classification: #{classification}" unless classification.to_s.strip.empty?
    version = meta.dig('iso27001', 'version')
    lines << "version: #{version}" unless version.to_s.strip.empty?
    lines.join("\n")
  end
end
