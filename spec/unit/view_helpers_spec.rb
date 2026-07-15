# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ViewHelpers do
  include described_class

  describe '#text_form_draft_baseline' do
    it 'maps editable field values and optional document title' do
      baseline = text_form_draft_baseline({ about_us: 'Saved text' }, document_title: 'Audit 1')
      expect(baseline).to eq('about_us' => 'Saved text', 'document_title' => 'Audit 1')
    end

    it 'omits document title when not provided' do
      baseline = text_form_draft_baseline({ scope: 'Global' })
      expect(baseline).to eq('scope' => 'Global')
    end
  end

  describe '#table_form_draft_baseline' do
    it 'indexes rows by _row_id without the internal key' do
      baseline = table_form_draft_baseline([
                                             { '_row_id' => 'r1', 'standard' => 'GDPR', 'requirement' => 'Comply' }
                                           ])
      expect(baseline).to eq('rows' => { 'r1' => { 'standard' => 'GDPR', 'requirement' => 'Comply' } })
    end
  end
end
