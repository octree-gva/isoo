# frozen_string_literal: true

require 'fileutils'
require_relative '../spec_helper'

RSpec.describe ProjectCreator do
  it 'copies template and commits' do
    Dir.mktmpdir do |tmp|
      tpl = File.join(tmp, 'templates', 'voca')
      FileUtils.mkdir_p(tpl)
      File.write(File.join(tpl, 'manifest.yaml'), { 'name' => 'Voca', 'documents' => [] }.to_yaml)
      File.write(File.join(tpl, 'index.md'), "# index\n")

      git = GitService.new(tmp)
      creator = ProjectCreator.new(data_root: tmp, git: git)
      creator.create(name: 'Acme', slug: 'acme', author: 'test@example.com')
      expect(File.directory?(File.join(tmp, 'projects', 'acme'))).to be true
    end
  end

  it 'moves forms out of documents and removes form stamps' do
    Dir.mktmpdir do |tmp|
      ph_path = File.join(tmp, 'templates', 'voca', 'audit', 'audit-report-template')
      FileUtils.mkdir_p(ph_path)
      File.write(File.join(ph_path, 'audit-report-template.md'), "---\ntitle: Audit\n---\n")
      File.write(File.join(ph_path, 'audit-report-template.schema.yaml'), "kind: form\nresponse_kind: text\n")

      File.write(File.join(tmp, 'templates', 'voca', 'manifest.yaml'), {
        'name' => 'Voca',
        'documents' => [
          { 'doc_id' => 'audit-report-template', 'path' => 'audit/audit-report-template',
            'kind' => 'form', 'response_kind' => 'text', 'title' => 'Audit Report' }
        ]
      }.to_yaml)
      File.write(File.join(tmp, 'templates', 'voca', 'index.md'), "# index\n")

      ProjectCreator.new(data_root: tmp).create(name: 'Acme', slug: 'acme', author: 'test@example.com')
      manifest = ProjectManifest.load(File.join(tmp, 'projects', 'acme'))
      expect(manifest.documents).to be_empty
      expect(manifest.forms.size).to eq(1)
      expect(manifest.forms.first['responses']).to eq([])
      stamp = File.join(tmp, 'projects', 'acme', 'audit/audit-report-template/audit-report-template.md')
      expect(File.file?(stamp)).to be false
    end
  end

  it 'preserves ISMS RASCI seed rows from the template' do
    Dir.mktmpdir do |tmp|
      tpl_root = File.join(tmp, 'templates', 'voca')
      basic_path = File.join(tpl_root, 'documents', 'isms-rasci-matrix-basic-accountability-matrix')
      FileUtils.mkdir_p(basic_path)
      File.write(
        File.join(basic_path, 'isms-rasci-matrix-basic-accountability-matrix.csv'),
        "iso270012022_isms_accountability,responsible_named_person,accountable_named_person,_row_id,_deleted_at\n" \
        "4 Context of the organisation,,,seed-row-id,\n"
      )
      File.write(
        File.join(basic_path, 'isms-rasci-matrix-basic-accountability-matrix.md'),
        "---\ntitle: RASCI Basic\niso27001:\n  classification: Confidential\n  version: 0.1.0\n---\n"
      )
      File.write(
        File.join(basic_path, 'isms-rasci-matrix-basic-accountability-matrix.schema.yaml'),
        "kind: table\nprimary_key: iso270012022_isms_accountability\ncolumns: []\n_internal: []\n"
      )
      File.write(File.join(tpl_root, 'manifest.yaml'), {
        'name' => 'Voca',
        'documents' => [
          { 'doc_id' => 'isms-rasci-matrix-basic-accountability-matrix',
            'path' => 'documents/isms-rasci-matrix-basic-accountability-matrix',
            'kind' => 'table', 'title' => 'RASCI Basic' }
        ]
      }.to_yaml)
      File.write(File.join(tpl_root, 'index.md'), "# index\n")

      ProjectCreator.new(data_root: tmp).create(name: 'Acme', slug: 'acme', author: 'test@example.com')
      csv_enc = File.join(tmp, 'projects', 'acme', 'documents', 'isms-rasci-matrix-basic-accountability-matrix',
                          'isms-rasci-matrix-basic-accountability-matrix.csv.enc')
      expect(File.file?(csv_enc)).to be(true)
      store = ClassifiedFileStore.new(FileStore.new(File.join(tmp, 'projects', 'acme')))
      rows = CSV.parse(store.read(
                         'documents/isms-rasci-matrix-basic-accountability-matrix/' \
                         'isms-rasci-matrix-basic-accountability-matrix.csv'
                       ), headers: true)
      expect(rows.size).to eq(1)
      expect(rows.first['iso270012022_isms_accountability']).to include('Context of the organisation')
    end
  end

  it 'moves file annexes out of documents into annexes' do
    Dir.mktmpdir do |tmp|
      annex_path = File.join(tmp, 'templates', 'voca', 'annexes', 'network-diagram')
      FileUtils.mkdir_p(annex_path)
      File.write(File.join(annex_path, 'network-diagram.md'), "---\ntitle: Network\n---\n")
      File.write(File.join(annex_path, 'network-diagram.schema.yaml'), "kind: file_annex\n")

      File.write(File.join(tmp, 'templates', 'voca', 'manifest.yaml'), {
        'name' => 'Voca',
        'documents' => [
          { 'doc_id' => 'network-diagram', 'path' => 'annexes/network-diagram',
            'kind' => 'file_annex', 'title' => 'Network diagram' }
        ]
      }.to_yaml)
      File.write(File.join(tmp, 'templates', 'voca', 'index.md'), "# index\n")

      ProjectCreator.new(data_root: tmp).create(name: 'Acme', slug: 'acme', author: 'test@example.com')
      manifest = ProjectManifest.load(File.join(tmp, 'projects', 'acme'))
      expect(manifest.documents).to be_empty
      expect(manifest.annexes.size).to eq(1)
      expect(manifest.annexes.first['doc_id']).to eq('network-diagram')
    end
  end
end
