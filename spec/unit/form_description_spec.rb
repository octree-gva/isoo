# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe FormDescription do
  it 'reads description from the form schema when manifest has none' do
    Dir.mktmpdir do |tmp|
      form_path = File.join(tmp, 'audit', 'audit-report-template')
      FileUtils.mkdir_p(form_path)
      File.write(File.join(form_path, 'audit-report-template.schema.yaml'), {
        'kind' => 'form',
        'response_kind' => 'text',
        'description' => "Explain what auditors should capture.\nOne line per topic.",
        'sections' => []
      }.to_yaml)

      store = FileStore.new(tmp)
      form = {
        'doc_id' => 'audit-report-template',
        'path' => 'audit/audit-report-template',
        'title' => 'Audit Report'
      }

      expect(FormDescription.resolve(form, store: store)).to eq(
        "Explain what auditors should capture.\nOne line per topic."
      )
    end
  end

  it 'prefers manifest description over schema' do
    Dir.mktmpdir do |tmp|
      form_path = File.join(tmp, 'forms', 'sample-form')
      FileUtils.mkdir_p(form_path)
      File.write(File.join(form_path, 'sample-form.schema.yaml'), {
        'kind' => 'form',
        'response_kind' => 'text',
        'description' => 'From schema',
        'sections' => []
      }.to_yaml)

      store = FileStore.new(tmp)
      form = {
        'doc_id' => 'sample-form',
        'path' => 'forms/sample-form',
        'title' => 'Sample',
        'description' => 'From manifest'
      }

      expect(FormDescription.resolve(form, store: store)).to eq('From manifest')
    end
  end

  it 'falls back to the voca template schema when the project copy is missing' do
    tmp = File.join(Dir.mktmpdir, 'data')
    template_path = File.join(tmp, 'templates', 'voca', 'continuity', 'business-continuity-plan')
    FileUtils.mkdir_p(template_path)
    File.write(File.join(template_path, 'business-continuity-plan.schema.yaml'), {
      'kind' => 'form',
      'response_kind' => 'text',
      'description' => 'How the business resists to crisis',
      'sections' => []
    }.to_yaml)

    store = FileStore.new(File.join(tmp, 'projects', 'demo'))
    form = {
      'doc_id' => 'business-continuity-plan',
      'path' => 'continuity/business-continuity-plan',
      'title' => 'Business Continuity Plan'
    }

    expect(FormDescription.resolve(form, store: store, data_root: tmp)).to eq(
      'How the business resists to crisis'
    )
  end
end
