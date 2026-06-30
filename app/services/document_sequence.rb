# frozen_string_literal: true

class DocumentSequence
  DEFAULT = 999_999

  def self.resolve(doc, meta: nil, store: nil)
    return doc['seq'].to_i if doc['seq']

    seq = meta&.dig('iso27001', 'seq')
    return seq.to_i if seq

    from_store(store, doc['path']) if store && doc['path']
  end

  def self.from_store(store, path)
    md = OkfPaths.md(path)
    return DEFAULT unless store.exist?(md)

    meta, = FrontMatter.parse(store.read(md))
    meta.dig('iso27001', 'seq') || DEFAULT
  rescue StandardError
    DEFAULT
  end

  def self.sort_key(doc, meta: nil, store: nil)
    [resolve(doc, meta: meta, store: store) || DEFAULT, doc['title'].to_s.downcase, doc['doc_id'].to_s]
  end
end
