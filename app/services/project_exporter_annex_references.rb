# frozen_string_literal: true

require 'csv'
require 'yaml'

require_relative 'annex_reference'
require_relative 'annex_reference_resolver'
require_relative 'export_annex_assets'
require_relative 'export_content'

module ProjectExporterAnnexReferences
  def referenced_annexes_html(entry)
    build_referenced_annexes(entry) do |annex_id, annex_doc_id, title, version|
      ExportAnnexAssets.new(@root).referenced_html_for(
        annex_id,
        doc_id: annex_doc_id,
        title: title,
        document_version: version
      )
    end.join("\n")
  end

  def referenced_annexes_markdown(entry)
    sections = build_referenced_annexes(entry) do |annex_id, annex_doc_id, title, version|
      ExportAnnexAssets.new(@root).referenced_markdown_for(
        annex_id,
        doc_id: annex_doc_id,
        title: title,
        document_version: version
      )
    end
    return '' if sections.empty?

    heading = "## #{IsooI18n.t('export.assets.referenced_heading')}\n\n"
    heading + sections.join("\n\n")
  end

  def export_body_markdown(entry, link_resolver)
    body = AnnexReference.rewrite_markdown(entry.body.to_s, resolver: annex_reference_resolver)
    ExportContent.demote_headings(link_resolver.rewrite_markdown(body))
  end

  def annex_reference_resolver
    @annex_reference_resolver ||= AnnexReferenceResolver.new(@manifest, store: @store, project_root: @root)
  end

  private

  def build_referenced_annexes(entry)
    resolver = annex_reference_resolver
    resolvable_annex_references(entry).filter_map do |annex_doc_id|
      annex_id = resolver.annex_id_for(annex_doc_id)
      next unless annex_id

      title = resolver.title_for(annex_doc_id)
      version = resolver.document_version_for(annex_doc_id)
      section = yield(annex_id, annex_doc_id, title, version)
      section.to_s.strip.empty? ? nil : section
    end
  end

  def resolvable_annex_references(entry)
    resolver = annex_reference_resolver
    collect_annex_references(entry).select { |doc_id| resolver.resolve(doc_id) }
  end

  def collect_annex_references(entry)
    refs = AnnexReference.extract_ordered(entry.body.to_s)
    return refs if entry.csv_text.to_s.strip.empty?

    schema = load_table_schema(entry.doc['path'])
    refs.concat(extract_csv_annex_references(entry.csv_text, schema))
    refs.uniq
  end

  def extract_csv_annex_references(csv_text, schema)
    return [] unless schema

    keys = Array(schema['columns']).select { |col| ExportContent.textarea_column?(col) }
                                   .map { |col| col['key'].to_s }
    return [] if keys.empty?

    table = CSV.parse(csv_text, headers: true)
    ordered = []
    seen = {}
    table.each do |row|
      next if row['_deleted_at'].to_s != ''

      keys.each do |key|
        AnnexReference.extract_ordered(row[key]).each do |doc_id|
          next if seen[doc_id]

          seen[doc_id] = true
          ordered << doc_id
        end
      end
    end
    ordered
  end
end
