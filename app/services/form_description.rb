# frozen_string_literal: true

require 'yaml'

class FormDescription
  def self.resolve(form, store:, data_root: nil, template_id: 'voca')
    manifest_desc = form['description'].to_s.strip
    return manifest_desc unless manifest_desc.empty?

    description = read_schema_description(store, form['path'], form['doc_id'])
    return description unless description.empty?

    template_path = template_schema_path(data_root, template_id, form)
    read_schema_file(template_path)
  end

  def self.read_schema_description(store, form_path, _doc_id)
    schema_path = OkfPaths.schema(form_path)
    return '' unless store.exist?(schema_path)

    schema = YAML.safe_load(store.read(schema_path)) || {}
    schema['description'].to_s.strip
  rescue Psych::SyntaxError
    ''
  end

  def self.read_schema_file(path)
    return '' unless path && File.file?(path)

    schema = YAML.safe_load_file(path) || {}
    schema['description'].to_s.strip
  rescue Psych::SyntaxError
    ''
  end

  def self.template_schema_path(data_root, template_id, form)
    return nil unless data_root

    File.join(data_root, 'templates', template_id, form['path'], "#{form['doc_id']}.schema.yaml")
  end

  private_class_method :read_schema_description, :read_schema_file, :template_schema_path
end
