# frozen_string_literal: true

class MarkdownExporter
  def initialize(project_root, store: nil)
    @exporter = ProjectExporter.new(project_root, store: store)
  end

  def export
    @exporter.export_markdown
  end
end
