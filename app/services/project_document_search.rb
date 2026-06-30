# frozen_string_literal: true

require 'cgi'
require 'csv'

class ProjectDocumentSearch
  Hit = Struct.new(:doc_id, :title, :kind, :url, :snippet, :matches, keyword_init: true)

  SNIPPET_RADIUS = 60

  def initialize(manifest:, store:, slug:)
    @manifest = manifest
    @store = store
    @slug = slug
  end

  def search(query)
    terms = normalize_terms(query)
    return [] if terms.empty?

    all_documents.filter_map do |doc|
      haystack = searchable_text(doc)
      next unless matches?(haystack, terms)

      Hit.new(
        doc_id: doc['doc_id'],
        title: doc['title'] || doc['doc_id'],
        kind: doc['kind'],
        url: document_url(doc),
        snippet: snippet(haystack, terms),
        matches: match_count(haystack, terms)
      )
    end.sort_by { |hit| [-hit.matches, hit.title.downcase] }
  end

  private

  def normalize_terms(query)
    query.to_s.strip.split(/\s+/).reject(&:empty?)
  end

  def all_documents
    docs = @manifest.documents.dup
    @manifest.annexes.each { |annex| docs << annex }
    @manifest.forms.each do |form|
      form.fetch('responses', []).each do |response|
        docs << response.merge(
          'kind' => form.fetch('response_kind', 'text'),
          'title' => response['title'] || response['doc_id']
        )
      end
    end
    docs
  end

  def searchable_text(doc)
    parts = [doc['title'], doc['description']].compact
    path = doc['path']
    return parts.compact.join("\n") unless path

    md_path = OkfPaths.md(path)
    if @store.exist?(md_path)
      _meta, body = FrontMatter.parse(@store.read(md_path))
      parts << body
    end

    csv_path = OkfPaths.csv(path)
    parts << @store.read(csv_path) if @store.exist?(csv_path)

    parts.compact.join("\n")
  end

  def matches?(haystack, terms)
    down = haystack.downcase
    terms.all? { |term| down.include?(term.downcase) }
  end

  def match_count(haystack, terms)
    down = haystack.downcase
    terms.sum { |term| down.scan(term.downcase).length }
  end

  def snippet(haystack, terms)
    term = terms.find { |t| haystack.downcase.include?(t.downcase) }
    return nil unless term

    idx = haystack.downcase.index(term.downcase)
    start = [idx - SNIPPET_RADIUS, 0].max
    length = term.length + (SNIPPET_RADIUS * 2)
    excerpt = haystack[start, length].gsub(/\s+/, ' ').strip
    excerpt = "...#{excerpt}" if start.positive?
    excerpt += '...' if (start + length) < haystack.length
    CGI.escapeHTML(excerpt)
  end

  def document_url(doc)
    "/projects/#{@slug}/docs/#{doc['doc_id']}"
  end
end
