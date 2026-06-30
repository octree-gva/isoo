# frozen_string_literal: true

require 'yaml'

class ExportTagAssigner
  BASIC_IDS = %w[
    organisation-overview
    the-information-security-management-system-overview
    documented-isms-scope
    is-01-information-security-policy
    0c-iso-27001-implementation-checklist
    information-security-manager-job-description
    isms-rasci-matrix-basic-accountability-matrix
  ].freeze

  DATA_PROTECTION_IDS = %w[
    dp-01-data-protection-policy
    dp-02-data-retention-policy
    data-asset-register-ropa
    legal-and-contractual-requirements-register
    incident-and-breach-reporting-form
    is-05-information-classification-and-handling-policy
    is-18-information-transfer-policy
    statement-of-applicability-iso-27002-2022-and-2013
    context-of-organisation
  ].freeze

  SOI_IDS = %w[
    physical-and-virtual-assets-register
    software-license-assets-register
    role-based-access-control
    starter-leaver-mover-access-register
    starter-leaver-mover-system-access-process
    competency-matrix
    operations-security-manual-v1
    how-to-access-control-and-role-based-access
    information-security-management-system-document-tracker
    network-diagram
    architectural-schema
    organisation-overview
  ].freeze

  def initialize(bundle_path)
    @bundle_path = bundle_path
    @registry = ExportTagRegistry.load(File.join(bundle_path, 'export_tags.yaml'))
  end

  def sync!
    updated = 0
    each_schema do |doc_id, path, schema_path|
      tags = tags_for(doc_id, path)
      tags.each { |tag| validate_tag!(tag) }
      next unless write_tags(schema_path, tags)

      updated += 1
    end
    updated
  end

  def tags_for(doc_id, path)
    tags = []
    tags << 'basic' if BASIC_IDS.include?(doc_id)
    tags << 'data_protection' if DATA_PROTECTION_IDS.include?(doc_id) || doc_id.start_with?('dp-')
    tags << 'soi' if SOI_IDS.include?(doc_id) || path.start_with?('annexes/')
    tags.uniq.sort
  end

  private

  def each_schema
    manifest_path = File.join(@bundle_path, 'manifest.yaml')
    return unless File.file?(manifest_path)

    manifest = YAML.safe_load_file(manifest_path) || {}
    Array(manifest['documents']).each do |doc|
      schema_path = File.join(@bundle_path, OkfPaths.schema(doc['path']))
      yield doc['doc_id'], doc['path'], schema_path if File.file?(schema_path)
    end

    Dir.glob(File.join(@bundle_path, 'annexes', '*', '*.schema.yaml')).each do |schema_path|
      doc_id = File.basename(schema_path, '.schema.yaml')
      path = "annexes/#{doc_id}"
      yield doc_id, path, schema_path
    end
  end

  def validate_tag!(tag)
    return if @registry.known?(tag)

    raise ArgumentError, "unknown export tag: #{tag}"
  end

  def write_tags(schema_path, tags)
    schema = YAML.safe_load_file(schema_path) || {}
    current = Array(schema['export_tags']).map(&:to_s)
    return false if current == tags

    if tags.empty?
      schema.delete('export_tags')
    else
      schema['export_tags'] = tags
    end
    File.write(schema_path, schema.to_yaml)
    true
  end
end
