# frozen_string_literal: true

require 'fileutils'
require_relative '../spec_helper'

RSpec.describe TableDocumentStore do
  describe '#find_row' do
    it 'returns a row by _row_id' do
      Dir.mktmpdir do |tmp|
        doc_path = 'registers/starter-leaver-mover-access-register'
        base = File.join(tmp, doc_path)
        FileUtils.mkdir_p(base)
        File.write(File.join(base, 'starter-leaver-mover-access-register.md'), "---\ntitle: SLM\n---\n")
        File.write(File.join(base, 'starter-leaver-mover-access-register.schema.yaml'), {
          'kind' => 'table',
          'primary_key' => 'reference',
          'columns' => [{ 'key' => 'reference', 'type' => 'number' }]
        }.to_yaml)
        File.write(File.join(base, 'starter-leaver-mover-access-register.csv'), "reference,_row_id,_deleted_at\n")

        store = ClassifiedFileStore.new(FileStore.new(tmp))
        tds = described_class.new(store)
        row = tds.add_row(doc_path, 'reference' => '1')

        expect(tds.find_row(doc_path, row['_row_id'])).to include('reference' => '1')
        expect(tds.find_row(doc_path, 'missing')).to be_nil
      end
    end
  end
end
