# frozen_string_literal: true

require 'base64'
require 'cgi'

require_relative '../i18n'
require_relative 'annex_reference'

class ExportAnnexAssets
  IMAGE_EXTENSIONS = %w[png jpg jpeg gif webp svg].freeze
  MIME_TYPES = {
    'png' => 'image/png',
    'jpg' => 'image/jpeg',
    'jpeg' => 'image/jpeg',
    'gif' => 'image/gif',
    'webp' => 'image/webp',
    'svg' => 'image/svg+xml'
  }.freeze

  def initialize(project_root)
    @root = project_root
    @annex = AnnexStore.new(project_root)
    @files_dir = File.join(project_root, 'annexes', 'files')
  end

  def html_for(annex_id, doc_id:, document_version: nil)
    latest = @annex.latest_file(annex_id)
    return '' unless latest

    figure = image_figure(latest, doc_id: doc_id, document_version: document_version)
    return '' unless figure

    <<~HTML
      <section class="export-annex-assets">
        <h2>#{CGI.escapeHTML(IsooI18n.t('export.assets.heading'))}</h2>
        #{figure}
      </section>
    HTML
  end

  def referenced_html_for(annex_id, doc_id:, title:, document_version: nil)
    latest = @annex.latest_file(annex_id)
    return '' unless latest

    referenced_section(
      latest,
      doc_id: doc_id,
      title: title,
      document_version: document_version,
      anchor_id: AnnexReference.anchor_id(doc_id)
    )
  end

  def referenced_markdown_for(annex_id, doc_id:, title:, document_version: nil)
    latest = @annex.latest_file(annex_id)
    return '' unless latest

    anchor = AnnexReference.anchor_id(doc_id)
    figure = image_figure(latest, doc_id: doc_id, document_version: document_version)
    body = if figure
             ext = File.extname(latest['filename'].to_s).delete_prefix('.').downcase
             mime = MIME_TYPES.fetch(ext, 'application/octet-stream')
             path = File.join(@files_dir, latest['filename'])
             data_uri = "data:#{mime};base64,#{Base64.strict_encode64(File.binread(path))}"
             "![#{title}](#{data_uri})"
           else
             IsooI18n.t('export.assets.document_asset', name: title)
           end

    <<~MD.strip
      <a id="#{anchor}"></a>

      ### #{title}

      #{body}
    MD
  end

  private

  def referenced_section(version, doc_id:, title:, anchor_id:, document_version: nil)
    figure = image_figure(version, doc_id: doc_id, document_version: document_version)
    content = figure || %(<p class="export-annex-file">#{CGI.escapeHTML(IsooI18n.t('export.assets.document_asset',
                                                                                   name: title))}</p>)

    <<~HTML
      <section class="export-annex-assets" id="#{CGI.escapeHTML(anchor_id)}">
        <h2>#{CGI.escapeHTML(title)}</h2>
        #{content}
      </section>
    HTML
  end

  def image_figure(version, doc_id:, document_version: nil)
    filename = version['filename'].to_s
    path = File.join(@files_dir, filename)
    return nil unless File.file?(path)

    ext = File.extname(filename).delete_prefix('.').downcase
    return nil unless IMAGE_EXTENSIONS.include?(ext)

    mime = MIME_TYPES.fetch(ext)
    data_uri = "data:#{mime};base64,#{Base64.strict_encode64(File.binread(path))}"
    doc_version = document_version.to_s.strip
    doc_version = version['document_version'].to_s.strip if doc_version.empty?
    caption = AnnexAssetName.label(
      doc_id: doc_id,
      document_version: doc_version,
      file_version: version['version']
    )

    <<~HTML.strip
      <figure class="export-annex-figure">
        <img src="#{data_uri}" alt="#{CGI.escapeHTML(caption)}">
        <figcaption>#{CGI.escapeHTML(caption)}</figcaption>
      </figure>
    HTML
  end
end
