# frozen_string_literal: true

require 'commonmarker'

class MarkdownRenderer
  def self.to_html(markdown)
    return '' if markdown.to_s.strip.empty?

    Commonmarker.to_html(
      markdown,
      options: {
        parse: { smart: true },
        render: { unsafe: false }
      }
    )
  end
end
