# frozen_string_literal: true

class AnnexReferenceResolver
  def initialize(manifest, store:, project_root:)
    @manifest = manifest
    @store = store
    @project_root = project_root
    @annex_docs = index_annexes
  end

  def title_for(doc_id)
    doc = @annex_docs[doc_id.to_s.downcase]
    return nil unless doc

    doc['title'].to_s.strip.empty? ? doc['doc_id'] : doc['title']
  end

  def resolve(doc_id)
    @annex_docs[doc_id.to_s.downcase]
  end

  def href_for(doc_id)
    "##{AnnexReference.anchor_id(doc_id)}"
  end

  def annex_id_for(doc_id)
    doc = resolve(doc_id)
    return nil unless doc

    meta = load_meta(doc['path'])
    aid = meta.dig('iso27001', 'annex_id')
    return aid if aid.to_s.strip != ''

    AnnexStore.new(@project_root).find_by_slug(doc['doc_id'])&.fetch('id', nil)
  end

  def document_version_for(doc_id)
    doc = resolve(doc_id)
    return nil unless doc

    meta = load_meta(doc['path'])
    meta.dig('iso27001', 'version')
  end

  def tag_scope_allows?(doc_id, scope:)
    return true if scope.to_s.empty? || scope.to_s == 'full'

    doc = resolve(doc_id)
    return false unless doc

    DocumentExportTags.matches?(doc, scope: scope, store: @store, manifest: @manifest)
  end

  private

  def index_annexes
    @manifest.annexes.to_h do |doc|
      [doc['doc_id'].to_s.downcase, doc]
    end
  end

  def load_meta(path)
    md_path = OkfPaths.md(path)
    return {} unless @store.exist?(md_path)

    meta, = FrontMatter.parse(@store.read(md_path))
    meta
  rescue Psych::SyntaxError
    {}
  end
end
