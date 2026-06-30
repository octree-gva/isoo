# frozen_string_literal: true

class ProjectDashboardItems
  Item = Struct.new(:kind, :seq, :doc, :extras, keyword_init: true)

  def self.build(manifest, store:)
    items = manifest.documents.map do |doc|
      Item.new(kind: :document, seq: DocumentSequence.resolve(doc, store: store), doc: doc)
    end
    annexes = manifest.annexes
    annex_seq = if annexes.any?
                  annexes.map { |annex| DocumentSequence.resolve(annex, store: store) }.min
                else
                  DocumentSequence::DEFAULT
                end
    items << Item.new(
      kind: :annexes,
      seq: annex_seq,
      doc: nil,
      extras: { annexes: annexes }
    )
    manifest.forms.each do |form|
      items << Item.new(
        kind: :form,
        seq: DocumentSequence.resolve(form, store: store),
        doc: form,
        extras: { response_count: form.fetch('responses', []).size }
      )
    end
    items.sort_by { |item| [item.seq, item.doc&.fetch('title', '').to_s.downcase] }
  end
end
