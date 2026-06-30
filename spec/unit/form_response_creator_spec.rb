# frozen_string_literal: true

require_relative '../spec_helper'
require 'fileutils'
require 'yaml'

RSpec.describe FormResponseCreator do
  it 'creates a numbered form response from a form definition' do
    tmp = File.join(Dir.mktmpdir, 'data')
    FileUtils.mkdir_p(File.join(tmp, 'projects', 'acme'))
    FileUtils.mkdir_p(File.join(tmp, 'templates', 'voca', 'audit', 'audit-report-template'))

    schema = {
      'schema_version' => '1', 'kind' => 'form', 'response_kind' => 'text',
      'sections' => [{ 'level' => 'h1', 'key' => 'title', 'label' => 'Title', 'role' => 'title' }]
    }
    File.write(
      File.join(tmp, 'templates', 'voca', 'audit', 'audit-report-template', 'audit-report-template.schema.yaml'),
      schema.to_yaml
    )
    File.write(
      File.join(tmp, 'templates', 'voca', 'audit', 'audit-report-template', 'audit-report-template.md'),
      "---\niso27001:\n  doc_id: audit-report-template\n---\n\n# Audit\n"
    )
    File.write(File.join(tmp, 'projects', 'acme', 'manifest.yaml'), {
      'name' => 'Acme',
      'documents' => [],
      'forms' => [{
        'doc_id' => 'audit-report-template',
        'path' => 'audit/audit-report-template',
        'title' => 'Audit Report',
        'response_kind' => 'text',
        'responses' => []
      }]
    }.to_yaml)

    id = FormResponseCreator.new(data_root: tmp).create(
      project_slug: 'acme', form_id: 'audit-report-template', author: 'test@example.com'
    )
    expect(id).to eq('audit-report-template-1')

    manifest = ProjectManifest.load(File.join(tmp, 'projects', 'acme'))
    expect(manifest.forms.first['responses'].size).to eq(1)

    inst_schema = YAML.safe_load_file(
      File.join(tmp, 'projects', 'acme', 'audit/audit-report-template/responses/audit-report-template-1',
                'audit-report-template-1.schema.yaml')
    )
    expect(inst_schema['kind']).to eq('text')
    expect(inst_schema).not_to have_key('response_kind')
  end
end
