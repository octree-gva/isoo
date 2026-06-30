# frozen_string_literal: true

class ExportLinkResolver
  MD_LINK = /\[(?<text>[^\]]*)\]\((?<url>[^)]+)\)/

  def self.build(manifest, exported_doc_ids:)
    index = {}
    each_manifest_doc(manifest) do |doc|
      path = doc['path'].to_s
      doc_id = doc['doc_id'].to_s
      basename = OkfPaths.basename(path)
      [
        doc_id,
        path,
        OkfPaths.md(path),
        basename,
        "#{basename}.md",
        "#{basename}.html"
      ].each { |key| index[key] = doc_id }
    end
    new(index, exported_doc_ids: exported_doc_ids)
  end

  def self.each_manifest_doc(manifest, &)
    manifest.documents.each(&)
    manifest.annexes.each(&)
    manifest.forms.each do |form|
      form.fetch('responses', []).each(&)
    end
  end

  def initialize(index, exported_doc_ids:)
    @index = index
    @exported_doc_ids = exported_doc_ids.to_set
  end

  def rewrite_markdown(text)
    return '' if text.to_s.empty?

    text.gsub(MD_LINK) do
      match = Regexp.last_match
      "[#{match[:text]}](#{resolve_href(match[:url])})"
    end
  end

  def rewrite_html(html)
    return '' if html.to_s.empty?

    html.gsub(/<a\s+([^>]*?)href="([^"]+)"([^>]*)>/i) do
      attrs_before = Regexp.last_match(1)
      href = Regexp.last_match(2)
      attrs_after = Regexp.last_match(3)
      %(<a #{attrs_before}href="#{CGI.escapeHTML(resolve_href(href))}"#{attrs_after}>)
    end
  end

  def resolve_href(url)
    stripped = url.to_s.strip
    return stripped if stripped.match?(/\A(https?:|#|mailto:)/i)

    target = lookup_doc_id(stripped)
    return "##{target}" if target && @exported_doc_ids.include?(target)

    stripped.sub(/\.md\z/i, '.html')
  end

  private

  def lookup_doc_id(url)
    clean = url.split('#').first.split('?').first
    return @index[clean] if @index[clean]

    basename = File.basename(clean)
    return @index[basename] if @index[basename]

    stem = basename.sub(/\.(md|html)\z/i, '')
    return @index[stem] if @index[stem]

    @index.each do |key, doc_id|
      return doc_id if key.to_s.end_with?("/#{basename}") || clean.end_with?("/#{basename}")
    end
    nil
  end
end
