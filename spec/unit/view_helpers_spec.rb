# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ViewHelpers do
  include described_class

  describe '#text_form_draft_baseline' do
    it 'maps editable field values and puts document title first' do
      baseline = text_form_draft_baseline({ about_us: 'Saved text' }, document_title: 'Audit 1')
      expect(baseline).to eq('document_title' => 'Audit 1', 'about_us' => 'Saved text')
      expect(baseline.keys).to eq(%w[document_title about_us])
    end

    it 'omits document title when not provided' do
      baseline = text_form_draft_baseline({ scope: 'Global' })
      expect(baseline).to eq('scope' => 'Global')
    end

    it 'normalizes switch sections to 1/0 for form capture parity' do
      sections = [{ 'key' => 'enabled', 'field_type' => 'switch' }]
      baseline = text_form_draft_baseline({ enabled: 'yes', notes: 'ok' }, sections: sections)
      expect(baseline).to eq('enabled' => '1', 'notes' => 'ok')
    end
  end

  describe '#table_form_draft_baseline' do
    it 'indexes rows by _row_id without the internal key' do
      baseline = table_form_draft_baseline([
                                             { '_row_id' => 'r1', 'standard' => 'GDPR', 'requirement' => 'Comply' }
                                           ])
      expect(baseline).to eq('rows' => { 'r1' => { 'standard' => 'GDPR', 'requirement' => 'Comply' } })
    end

    it 'omits owner and deleted-at keys that the form does not capture' do
      baseline = table_form_draft_baseline([
                                             {
                                               '_row_id' => 'r1',
                                               'standard' => 'GDPR',
                                               '_deleted_at' => '',
                                               'owner_name' => 'Ada',
                                               'owner_email' => 'ada@example.com'
                                             }
                                           ])
      expect(baseline).to eq('rows' => { 'r1' => { 'standard' => 'GDPR' } })
    end

    it 'emits only schema data columns and normalizes switches' do
      columns = [
        { 'key' => 'standard', 'type' => 'text' },
        { 'key' => 'active', 'type' => 'switch', 'default' => true }
      ]
      baseline = table_form_draft_baseline(
        [{ '_row_id' => 'r1', 'standard' => 'GDPR', 'active' => 'yes', 'owner_name' => 'Ada' }],
        columns: columns
      )
      expect(baseline).to eq('rows' => { 'r1' => { 'standard' => 'GDPR', 'active' => '1' } })
    end
  end

  describe '#document_owner_from_rows' do
    it 'accepts optional meta as a second positional argument' do
      rows = []
      meta = { 'iso27001' => { 'owner_name' => 'Ada', 'owner_email' => 'ada@example.com' } }
      expect(document_owner_from_rows(rows, meta)).to eq(
        'owner_name' => 'Ada',
        'owner_email' => 'ada@example.com'
      )
    end
  end
end
