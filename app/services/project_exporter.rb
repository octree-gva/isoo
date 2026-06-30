# frozen_string_literal: true

require 'csv'
require 'yaml'
require 'cgi'

require_relative '../i18n'
require_relative 'project_exporter_annex_references'

class ProjectExporter
  include ProjectExporterAnnexReferences
  Entry = Struct.new(:doc, :meta, :body, :csv_text, :version_control_html, keyword_init: true)

  EXPORT_TIER_MAIN = 0
  EXPORT_TIER_ANNEX = 1
  EXPORT_TIER_FORM_RESPONSE = 2

  def initialize(project_root, store: nil, slug: nil, export_scope: 'full')
    @root = project_root
    @store = store || ClassifiedFileStore.new(FileStore.new(project_root))
    @manifest = ProjectManifest.load(project_root)
    @slug = slug || File.basename(project_root)
    @export_scope = export_scope.to_s.empty? ? 'full' : export_scope.to_s
  end

  def export_markdown
    link_resolver = link_resolver_for
    out = "# #{@manifest.name} #{IsooI18n.t('export.markdown_suffix')}\n\n"
    entries.each do |entry|
      out += export_markdown_entry(entry, link_resolver)
    end
    out
  end

  def entries
    grouped = { EXPORT_TIER_MAIN => [], EXPORT_TIER_ANNEX => [], EXPORT_TIER_FORM_RESPONSE => [] }

    @manifest.documents.each { |doc| grouped[EXPORT_TIER_MAIN] << doc }
    @manifest.active_annexes.each { |doc| grouped[EXPORT_TIER_ANNEX] << doc }
    @manifest.forms.each do |form|
      form.fetch('responses', []).each do |response|
        grouped[EXPORT_TIER_FORM_RESPONSE] << response.merge(
          'kind' => form['response_kind'],
          'form_id' => form['doc_id']
        )
      end
    end

    collected = []
    [EXPORT_TIER_MAIN, EXPORT_TIER_ANNEX, EXPORT_TIER_FORM_RESPONSE].each do |tier|
      grouped[tier].each do |doc|
        entry = load_entry(doc)
        collected << entry if entry
      end
    end

    sort_within_tiers(collected)
    filter_by_export_scope(collected)
  end

  def html_entries
    link_resolver = link_resolver_for
    entries.map { |entry| present_html_entry(entry, link_resolver) }
  end

  def export_markdown_doc(doc_id)
    entry = entry_for(doc_id)
    return '' unless entry

    export_markdown_entry(entry, link_resolver_for_doc(entry.doc['doc_id']))
  end

  def html_entries_for_doc(doc_id)
    entry = entry_for(doc_id)
    return [] unless entry

    [present_html_entry(entry, link_resolver_for_doc(entry.doc['doc_id']))]
  end

  def entry_for(doc_id)
    doc = @manifest.resolve_document(doc_id)
    return nil unless doc

    load_entry(doc)
  end

  private

  def sort_within_tiers(collected)
    collected.sort_by do |entry|
      [
        export_tier(entry.doc),
        DocumentSequence.sort_key(entry.doc, meta: entry.meta, store: @store)
      ]
    end
  end

  def export_tier(doc)
    path = doc['path'].to_s
    return EXPORT_TIER_FORM_RESPONSE if path.include?('/responses/')
    return EXPORT_TIER_ANNEX if path.start_with?('annexes/') || doc['kind'] == 'file_annex'

    EXPORT_TIER_MAIN
  end

  def filter_by_export_scope(entries)
    return entries if @export_scope == 'full'

    entries.select do |entry|
      DocumentExportTags.matches?(
        entry.doc,
        scope: @export_scope,
        store: @store,
        manifest: @manifest
      )
    end
  end

  def link_resolver_for
    exported = entries
    ExportLinkResolver.build(@manifest, exported_doc_ids: exported.map { |e| e.doc['doc_id'] })
  end

  def link_resolver_for_doc(doc_id)
    ExportLinkResolver.build(@manifest, exported_doc_ids: [doc_id.to_s])
  end

  def load_entry(doc)
    path = doc['path']
    md = OkfPaths.md(path)
    return nil unless @store.exist?(md)

    raw = @store.read(md)
    meta, raw_body = FrontMatter.parse(raw)
    version_control_html = ExportContent.version_control_table_html(
      raw_body,
      current_version: meta.dig('iso27001', 'version'),
      meta: meta,
      audit: load_audit(md)
    )
    body = VersionControlWriter.strip_block(raw_body)
    body = ExportContent.strip_leading_version_rows(body)
    body = ExportContent.strip_schema_section(body)

    csv_text = nil
    csv = OkfPaths.csv(path)
    csv_text = @store.read(csv) if @store.exist?(csv)

    Entry.new(
      doc: doc,
      meta: meta,
      body: body,
      csv_text: csv_text,
      version_control_html: version_control_html
    )
  end

  def export_markdown_entry(entry, link_resolver)
    doc = entry.doc
    title = doc['title'] || doc['doc_id']
    out = "# #{title}\n\n"
    body = export_body_markdown(entry, link_resolver)
    out += "#{body}\n\n" unless body.strip.empty?
    if entry.csv_text
      out += "## #{IsooI18n.t('export.document.data_heading')}\n\n"
      out += "#{csv_to_markdown(entry, link_resolver)}\n\n"
    end
    referenced = referenced_annexes_markdown(entry)
    out += "#{referenced}\n\n" unless referenced.empty?
    out
  end

  def present_html_entry(entry, link_resolver)
    doc = entry.doc
    body_md = export_body_markdown(entry, link_resolver)
    body_html = MarkdownRenderer.to_html(body_md)
    body_html = link_resolver.rewrite_html(body_html)
    table_html = csv_to_html(entry, link_resolver)
    legend_html = table_legend_html(entry)
    assets_html = annex_assets_html(entry) + referenced_annexes_html(entry)

    {
      'doc_id' => doc['doc_id'],
      'title' => doc['title'] || doc['doc_id'],
      'seq' => DocumentSequence.resolve(doc, meta: entry.meta, store: @store),
      'group' => export_group(doc),
      'classification' => entry.meta.dig('iso27001', 'classification'),
      'version' => entry.meta.dig('iso27001', 'version'),
      'body_html' => body_html,
      'table_html' => table_html,
      'table_legend_html' => legend_html,
      'version_control_html' => entry.version_control_html,
      'annex_assets_html' => assets_html,
      'has_data_table' => !table_html.empty?,
      'export_tier' => export_tier_name(doc)
    }
  end

  def export_tier_name(doc)
    case export_tier(doc)
    when EXPORT_TIER_ANNEX then 'annex'
    when EXPORT_TIER_FORM_RESPONSE then 'form'
    else 'main'
    end
  end

  def annex_assets_html(entry)
    return '' unless file_annex?(entry.doc)

    annex_id = entry.meta.dig('iso27001', 'annex_id')
    return '' if annex_id.to_s.empty?

    ExportAnnexAssets.new(@root).html_for(
      annex_id,
      doc_id: entry.doc['doc_id'],
      document_version: entry.meta.dig('iso27001', 'version')
    )
  end

  def table_legend_html(entry)
    return '' if entry.csv_text.to_s.strip.empty?

    schema_path = OkfPaths.schema(entry.doc['path'])
    return '' unless @store.exist?(schema_path)

    schema = YAML.safe_load(@store.read(schema_path)) || {}
    return '' unless schema['kind'] == 'table'

    headers = CSV.parse(entry.csv_text, headers: true).headers
    ExportContent.table_legend_html(schema, csv_headers: headers)
  rescue Psych::SyntaxError
    ''
  end

  def file_annex?(doc)
    doc['kind'] == 'file_annex' || doc['path'].to_s.start_with?('annexes/')
  end

  def export_group(doc)
    segment = doc['path'].to_s.split('/').first.to_s
    key = "export.groups.#{segment}"
    translated = IsooI18n.t(key)
    return translated unless translated == key

    segment.tr('-', ' ').split.map(&:capitalize).join(' ')
  end

  def csv_to_html(entry, link_resolver)
    return '' if entry.csv_text.to_s.strip.empty?

    schema = load_table_schema(entry.doc['path'])
    ExportContent.csv_to_html(
      entry.csv_text,
      schema: schema,
      annex_resolver: annex_reference_resolver,
      link_resolver: link_resolver
    )
  end

  def csv_to_markdown(entry, link_resolver)
    schema = load_table_schema(entry.doc['path'])
    ExportContent.csv_to_markdown(
      entry.csv_text,
      schema: schema,
      annex_resolver: annex_reference_resolver,
      link_resolver: link_resolver
    )
  end

  def load_table_schema(path)
    schema_path = OkfPaths.schema(path)
    return nil unless @store.exist?(schema_path)

    schema = YAML.safe_load(@store.read(schema_path)) || {}
    schema['kind'] == 'table' ? schema : nil
  rescue Psych::SyntaxError
    nil
  end

  def load_audit(md_path)
    return {} unless @store.respond_to?(:audit)

    @store.audit(md_path) || {}
  rescue Psych::SyntaxError
    {}
  end
end
