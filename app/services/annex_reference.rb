# frozen_string_literal: true

class AnnexReference
  PATTERN = /\[ANNEX\s+([a-z0-9][a-z0-9-]*)\]/i

  def self.extract(text)
    text.to_s.scan(PATTERN).flatten.map(&:downcase).uniq
  end

  def self.extract_ordered(text)
    seen = {}
    text.to_s.scan(PATTERN).flatten.map(&:downcase).filter_map do |doc_id|
      next if seen[doc_id]

      seen[doc_id] = true
      doc_id
    end
  end

  def self.rewrite_markdown(text, resolver:)
    return '' if text.to_s.empty?

    text.gsub(PATTERN) do
      doc_id = Regexp.last_match(1).downcase
      title = resolver.title_for(doc_id)
      next Regexp.last_match(0) unless title

      "[#{title}](#{resolver.href_for(doc_id)})"
    end
  end

  def self.anchor_id(doc_id)
    "annex-ref-#{doc_id}"
  end
end
