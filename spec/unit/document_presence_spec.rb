# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe DocumentPresence do
  let(:store) { PresenceStore.build }
  let(:presence) { described_class.new(store: store) }

  it 'lists other editors and expires stale heartbeats' do
    presence.heartbeat(slug: 'demo', doc_id: 'doc-a', editor_id: 'alice', name: 'Alice')
    presence.heartbeat(slug: 'demo', doc_id: 'doc-a', editor_id: 'bob', name: 'Bob')

    others = presence.others(slug: 'demo', doc_id: 'doc-a', editor_id: 'alice')
    expect(others.map { |e| e['name'] }).to eq(['Bob'])

    presence.leave(slug: 'demo', doc_id: 'doc-a', editor_id: 'bob')
    expect(presence.others(slug: 'demo', doc_id: 'doc-a', editor_id: 'alice')).to eq([])
  end

  it 'isolates presence by project and document' do
    presence.heartbeat(slug: 'demo', doc_id: 'doc-a', editor_id: 'alice', name: 'Alice')
    expect(presence.others(slug: 'demo', doc_id: 'doc-b', editor_id: 'bob')).to eq([])
    expect(presence.others(slug: 'other', doc_id: 'doc-a', editor_id: 'bob')).to eq([])
  end
end
