# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe DocumentDescription do
  let(:doc) do
    {
      'doc_id' => '0c-iso-27001-implementation-checklist',
      'path' => 'documents/0c-iso-27001-implementation-checklist',
      'title' => '0C - ISO 27001 Implementation Checklist'
    }
  end

  it 'falls back to template guidance when project meta repeats the title' do
    meta = { 'description' => doc['title'] }

    text = DocumentDescription.resolve(meta, doc, data_root: App::DATA_PATH)

    expect(text).to include('step-by-step roadmap')
    expect(text).not_to eq(doc['title'])
  end

  it 'prefers a meaningful project meta description' do
    meta = { 'description' => 'Custom guidance for our team.' }

    expect(DocumentDescription.resolve(meta, doc, data_root: App::DATA_PATH)).to eq(
      'Custom guidance for our team.'
    )
  end

  it 'reads guidance from descriptions.yaml when meta and manifest are empty' do
    meta = {}

    text = DocumentDescription.resolve(meta, doc, data_root: App::DATA_PATH)

    expect(text).to include('Statement of Applicability')
  end

  it 'prefers project schema description over template guidance' do
    Dir.mktmpdir do |tmp|
      project_root = File.join(tmp, 'projects', 'acme')
      schema_dir = File.join(project_root, doc['path'])
      FileUtils.mkdir_p(schema_dir)
      File.write(
        File.join(schema_dir, "#{doc['doc_id']}.schema.yaml"),
        { 'description' => 'Project copy with ![diagram](/img/ism_overview.png)' }.to_yaml
      )

      text = DocumentDescription.resolve({}, doc, data_root: tmp, project_root: project_root)

      expect(text).to include('![diagram](/img/ism_overview.png)')
    end
  end
end
