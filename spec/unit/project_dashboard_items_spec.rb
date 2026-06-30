# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ProjectDashboardItems do
  let(:manifest) do
    data = {
      'documents' => [{ 'doc_id' => 'overview', 'title' => 'Overview', 'seq' => 1, 'kind' => 'text',
                        'path' => 'context/overview' }],
      'forms' => [{ 'doc_id' => 'meeting', 'title' => 'Meeting', 'seq' => 2, 'responses' => [] }],
      'annexes' => []
    }
    ProjectManifest.new('/tmp/test', data)
  end

  it 'always includes the annexes folder even when there are no annexes' do
    items = described_class.build(manifest, store: nil)
    kinds = items.map(&:kind)

    expect(kinds).to include(:annexes)
    annex_item = items.find { |item| item.kind == :annexes }
    expect(annex_item.extras[:annexes]).to eq([])
  end

  it 'lists form folders from the manifest' do
    items = described_class.build(manifest, store: nil)
    form_items = items.select { |item| item.kind == :form }

    expect(form_items.size).to eq(1)
    expect(form_items.first.extras[:response_count]).to eq(0)
  end
end
