# frozen_string_literal: true

require_relative '../spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe AnnexReferenceIndex do
  def write_doc(root, path, doc_id, body:, csv: nil)
    dir = File.join(root, path)
    FileUtils.mkdir_p(dir)
    basename = File.basename(path)
    meta = { 'iso27001' => { 'doc_id' => doc_id, 'version' => '0.1.0' } }
    File.write(File.join(dir, "#{basename}.md"), FrontMatter.dump(meta, body))
    return unless csv

    File.write(File.join(dir, "#{basename}.csv"), csv)
  end

  it 'lists documents and form responses that reference an annex' do
    Dir.mktmpdir do |tmp|
      File.write(File.join(tmp, 'manifest.yaml'), {
        'name' => 'Test',
        'documents' => [
          { 'doc_id' => 'overview', 'title' => 'Overview', 'path' => 'context/overview' },
          { 'doc_id' => 'register', 'title' => 'Register', 'path' => 'registers/register' },
          { 'doc_id' => 'diagram', 'title' => 'Diagram', 'path' => 'annexes/diagram', 'kind' => 'file_annex' }
        ],
        'forms' => [
          {
            'doc_id' => 'audit-form',
            'title' => 'Audit Form',
            'path' => 'audit/audit-form',
            'response_kind' => 'text',
            'responses' => [
              { 'doc_id' => 'audit-form-1', 'title' => 'Audit 1',
                'path' => 'audit/audit-form/responses/audit-form-1' }
            ]
          }
        ]
      }.to_yaml)

      write_doc(tmp, 'context/overview', 'overview', body: "See [ANNEX diagram].\n")
      write_doc(tmp, 'registers/register', 'register', body: "# Register\n",
                                                       csv: "notes,_row_id,_deleted_at\n[ANNEX diagram],rid-1,\n")
      File.write(File.join(tmp, 'registers/register', 'register.schema.yaml'), {
        'kind' => 'table',
        'columns' => [{ 'key' => 'notes', 'label' => 'Notes', 'type' => 'textarea' }]
      }.to_yaml)
      write_doc(tmp, 'audit/audit-form/responses/audit-form-1', 'audit-form-1', body: "Audit [ANNEX diagram]\n")
      write_doc(tmp, 'annexes/diagram', 'diagram', body: "# Diagram\n")

      store = ClassifiedFileStore.new(FileStore.new(tmp))
      manifest = ProjectManifest.load(tmp)
      index = described_class.new(manifest, store: store)
      entries = index.referencing_entries('diagram')

      expect(entries.map { |entry| entry['doc_id'] }).to eq(%w[overview register audit-form-1])
      expect(entries.map { |entry| entry['kind'] }).to eq(%w[document table form_response])
    end
  end
end
