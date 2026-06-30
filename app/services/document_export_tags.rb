# frozen_string_literal: true

require 'yaml'

class DocumentExportTags
  def self.for_doc(doc, store:, manifest: nil)
    schema_path = schema_path_for(doc, manifest)
    return [] unless schema_path && store.exist?(schema_path)

    schema = YAML.safe_load(store.read(schema_path)) || {}
    Array(schema['export_tags']).map(&:to_s).reject(&:empty?)
  rescue Psych::SyntaxError
    []
  end

  def self.matches?(doc, scope:, store:, manifest: nil)
    return true if scope.to_s.empty? || scope.to_s == 'full'

    for_doc(doc, store: store, manifest: manifest).include?(scope.to_s)
  end

  def self.schema_path_for(doc, manifest)
    path = doc['path'].to_s
    return OkfPaths.schema(path) unless path.include?('/responses/')

    form_id = doc['form_id']
    if form_id && manifest
      form = manifest.find_form(form_id)
      return OkfPaths.schema(form['path']) if form
    end

    OkfPaths.schema(path)
  end

  private_class_method :schema_path_for
end
