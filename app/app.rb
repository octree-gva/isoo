# frozen_string_literal: true

require 'roda'
require 'yaml'
require 'securerandom'
require 'json'
require 'base64'

require_relative 'i18n'
require_relative 'table_switch'
require_relative 'json_attr'
require_relative 'view_helpers'
require_relative 'data_layout'
require_relative 'container'
require_relative 'session_idle'
require_relative 'errors'
require_relative 'routes/observability'
require_relative 'routes/git'
Dir[File.join(__dir__, 'services', '*.rb')].each { |f| require f }

class App < Roda
  include ViewHelpers
  include RoutesObservability
  include RoutesGit

  plugin :render,
         views: File.join(__dir__, 'views'),
         layout: 'layouts/app',
         cache: ENV.fetch('RACK_ENV', 'development') == 'production' do
    include ViewHelpers
  end
  plugin :public
  plugin :all_verbs
  plugin :error_handler do |e|
    case e
    when IsooHttpError
      @error_status = e.status
      @error_detail = e.detail
    else
      warn "[App] #{e.class}: #{e.message}\n#{e.backtrace&.first(8)&.join("\n")}"
      @error_status = 500
      @error_detail = nil
    end
    @error_title = t("errors.#{@error_status}.title")
    @error_message = t("errors.#{@error_status}.message")
    response.status = @error_status
    view('errors/show', layout: 'layouts/error')
  end
  plugin :not_found do
    @error_status = 404
    @error_detail = nil
    @error_title = t('errors.404.title')
    @error_message = t('errors.404.message')
    response.status = 404
    view('errors/show', layout: 'layouts/error')
  end

  DATA_PATH = DataLayout::DATA_PATH
  TEMPLATES_PATH = DataLayout::TEMPLATES_PATH

  DataLayout.ensure!

  def self.git
    Container.git
  end

  def self.projects
    Container.projects
  end

  def current_user
    return { 'email' => 'dev@local', 'name' => IsooI18n.t('auth.dev_user_name') } if ENV['AUTH_DISABLED'] == '1'

    @current_user ||= env['isoo.user']
  end

  def author_name
    u = current_user
    u&.dig('email') || u&.dig('name') || IsooI18n.t('common.unknown')
  end

  def project_manifest(slug)
    ProjectManifest.load(File.join(DATA_PATH, 'projects', slug))
  end

  def resolve_doc(manifest, doc_id)
    manifest.resolve_document(doc_id)
  end

  def doc_meta(slug, doc_path)
    store = @store || classified_store(slug)
    md = OkfPaths.md(doc_path)
    meta, = FrontMatter.parse(store.read(md))
    meta
  end

  def classified_store(slug)
    Container.classified_store(File.join(DATA_PATH, 'projects', slug), scope: "project:#{slug}")
  end

  def rack_session
    env['rack.session'] || {}
  end

  def normalize_flash(value)
    return nil if value.nil? || value == ''

    return value if value.is_a?(Hash) && value['message'].to_s != ''

    { 'message' => value.to_s, 'type' => 'error' }
  end

  def flash_success(key, **)
    rack_session['flash'] = { 'message' => t(key, **), 'type' => 'success' }
  end

  def flash_error(message)
    rack_session['flash'] = { 'message' => message, 'type' => 'error' }
  end

  def commit_and_redirect!(r, path, commit_message:, toast_key:, significant: false, bump_project_version: true,
                           **toast_args)
    bump_project_version!(significant: significant) if bump_project_version
    self.class.git.commit(commit_message)
    flash_success(toast_key, **toast_args)
    r.redirect(path)
  end

  def bump_project_version!(significant:)
    @manifest.bump_version!(significant: significant)
  end

  def http_error!(status, detail: nil, detail_key: nil, **i18n_opts)
    raise IsooHttpError.new(status, detail: detail, detail_key: detail_key, **i18n_opts)
  end

  def presence_editor_id
    rack_session['presence_id'] ||= SecureRandom.uuid
  end

  route do |r|
    @flash = normalize_flash(rack_session.delete('flash'))
    r.public
    r.on('health') { routes_health(r) }
    r.get('metrics') { routes_metrics(r) }
    r.on('git') { routes_git(r) }
    r.on 'projects' do
      routes_projects(r)
    end
    r.root { r.redirect('/projects') }
  end

  def routes_projects(r)
    r.is do
      r.get do
        @projects = self.class.projects.list
        @project_template = Container.template_info
        @content_class = 'max-w-3xl has-page-footer'
        view('projects/index')
      end
      r.post { create_project(r) }
    end

    r.on String do |slug|
      routes_project_slug(r, slug)
    end
  end

  def routes_project_slug(r, slug)
    @slug = slug
    @manifest = project_manifest(slug)
    @project_root = File.join(DATA_PATH, 'projects', slug)
    project_root = @project_root
    @store = classified_store(slug)
    @annexes = []

    r.is { r.get { render_project_show(slug, query: r.params['q']) } }
    r.get('reviews') { render_project_reviews }
    r.get('export') { render_project_export(r, slug, project_root) }
    r.get('export.md') { r.redirect("/projects/#{slug}/export?format=md") }
    r.on('annexes') do
      r.is do
        r.get { render_project_annexes(slug) }
        r.post { create_annex(r, slug) }
      end
      r.on(Integer) { |aid| download_annex(r, project_root, aid) }
    end
    r.on('forms', String) do |form_id|
      routes_form(r, slug, form_id)
    end
    r.on('docs', String) { |doc_id| routes_doc(r, slug, project_root, doc_id) }
  end

  def create_project(r)
    name = r.params['name'].to_s.strip
    slug = normalize_project_slug(r.params['slug'])

    if name.empty?
      flash_error(t('errors.details.name_required'))
      return r.redirect('/projects')
    end
    if slug.empty?
      flash_error(t('errors.details.slug_required'))
      return r.redirect('/projects')
    end

    self.class.projects.create(name: name, slug: slug, author: author_name)
    flash_success('toast.project_created', name: name)
    r.redirect("/projects/#{slug}")
  rescue ArgumentError => e
    case e.message
    when 'project exists'
      flash_error(t('toast.project_exists', slug: slug))
    when 'template missing'
      flash_error(t('toast.template_missing'))
    else
      raise
    end
    r.redirect('/projects')
  end

  def normalize_project_slug(raw)
    raw.to_s.strip.downcase.gsub(/[^a-z0-9-]+/, '-').gsub(/\A-+|-+\z/, '')
  end

  def render_project_show(slug, query: nil)
    @navbar_export = true
    @search_query = query.to_s.strip
    @search_results = []
    @dashboard_items = ProjectDashboardItems.build(@manifest, store: @store).map do |item|
      case item.kind
      when :document
        item.doc = enrich_dashboard_doc(slug, item.doc)
      when :form
        item.doc = enrich_dashboard_form(slug, item.doc)
      when :annexes
        item.extras[:annexes] = item.extras[:annexes].map { |doc| enrich_doc_meta(slug, doc) }
      end
      item
    end
    @docs = @manifest.documents.map { |doc| enrich_doc_meta(slug, doc) }
    @annexes = @manifest.annexes.map { |doc| enrich_doc_meta(slug, doc) }
    @forms = @manifest.forms.map do |form|
      form.merge('response_count' => form.fetch('responses', []).size)
    end
    @project_empty = @dashboard_items.empty?
    unless @search_query.empty?
      @search_results = ProjectDocumentSearch.new(manifest: @manifest, store: @store, slug: slug)
                                             .search(@search_query)
    end
    @export_tag_registry = ExportTagRegistry.for_project(File.join(DATA_PATH, 'projects', slug))
    view('projects/show')
  end

  def render_project_annexes(slug)
    @annexes = @manifest.annexes.map do |doc|
      enriched = enrich_doc_meta(slug, doc)
      annex_versions = annex_versions_for(slug, enriched)
      enriched.merge(
        'asset_kind' => AnnexAssetKind.resolve(enriched, annex_versions)
      )
    end
    view('projects/annexes')
  end

  def create_annex(r, slug)
    doc_id = AnnexCreator.new(data_root: DATA_PATH, git: self.class.git).create(
      project_slug: slug,
      author: author_name,
      title: r.params['title'],
      asset_kind: r.params['asset_kind']
    )
    flash_success('toast.annex_created')
    r.redirect("/projects/#{slug}/docs/#{doc_id}")
  end

  def render_project_reviews
    review = ProjectReview.new(manifest: @manifest, store: @store)
    @oldest_documents = review.oldest_editable_documents
    @stale_documents = review.stale_documents
    @expired_review_dates = review.expired_review_dates
    view('projects/reviews')
  end

  def enrich_doc_meta(slug, doc)
    meta = doc_meta(slug, doc['path'])
    doc.merge('version' => meta.dig('iso27001', 'version'), 'resource' => meta['resource'],
              'classification' => meta.dig('iso27001', 'classification'))
  end

  def enrich_dashboard_doc(slug, doc)
    enrich_doc_meta(slug, doc).merge(
      'export_tags' => DocumentExportTags.for_doc(doc, store: @store, manifest: @manifest)
    )
  end

  def enrich_dashboard_form(_slug, form)
    form.merge(
      'response_count' => form.fetch('responses', []).size,
      'export_tags' => DocumentExportTags.for_doc(form, store: @store, manifest: @manifest)
    )
  end

  def routes_form(r, slug, form_id)
    @form = @manifest.find_form(form_id)
    http_error!(404) unless @form

    @form_description = FormDescription.resolve(@form, store: @store, data_root: DATA_PATH)
    r.get { view('projects/form') }
    r.post('responses') { create_form_response(r, slug, form_id) }
  end

  def create_form_response(r, slug, form_id)
    FormResponseCreator.new(data_root: DATA_PATH, template_id: template_id_for(@manifest), git: self.class.git).create(
      project_slug: slug,
      form_id: form_id,
      author: author_name
    )
    flash_success('toast.form_response_created')
    r.redirect("/projects/#{slug}/forms/#{form_id}")
  end

  def render_project_export(r, slug, project_root)
    format = export_format_param(r.params['format'])
    scope = export_scope_param(r.params['scope'], project_root)
    exporter = ProjectExporter.new(project_root, store: @store, slug: slug, export_scope: scope)
    response['Cache-Control'] = 'no-store, no-cache, must-revalidate'
    response['Pragma'] = 'no-cache'

    export_html_url = "#{r.base_url}/projects/#{slug}/export?format=html&scope=#{scope}"

    case format
    when 'html'
      response['Content-Type'] = 'text/html; charset=utf-8'
      response['Content-Disposition'] = export_attachment(slug, 'html', scope: scope)
      export_html_bundle(exporter.html_entries, title: @manifest.export_title, display_url: export_html_url)
    when 'pdf'
      response['Content-Type'] = 'application/pdf'
      response['Content-Disposition'] = export_attachment(slug, 'pdf', scope: scope)
      ExportPdfRenderer.render(
        export_html_bundle(exporter.html_entries, title: @manifest.export_title, pdf_export: true,
                                                  display_url: export_html_url),
        display_url: export_html_url,
        title: @manifest.export_title,
        logo_data_uri: export_logo_data_uri,
        export_date: Time.now.utc.strftime('%Y-%m-%d')
      )
    else
      body = exporter.export_markdown
      response['Content-Type'] = 'text/markdown; charset=utf-8'
      response['Content-Disposition'] = export_attachment(slug, 'md', scope: scope)
      body
    end
  end

  def render_document_export(r, slug, project_root, doc_id)
    doc = resolve_doc(@manifest, doc_id)
    http_error!(404) unless doc

    format = export_format_param(r.params['format'])
    exporter = ProjectExporter.new(project_root, store: @store, slug: slug)
    title = doc['title'] || doc_id
    http_error!(404) if exporter.entry_for(doc_id).nil?

    response['Cache-Control'] = 'no-store, no-cache, must-revalidate'
    response['Pragma'] = 'no-cache'
    export_url = "#{r.base_url}/projects/#{slug}/docs/#{doc_id}/export?format=html"

    case format
    when 'html'
      response['Content-Type'] = 'text/html; charset=utf-8'
      response['Content-Disposition'] = doc_export_attachment(slug, doc_id, 'html')
      export_html_bundle(exporter.html_entries_for_doc(doc_id), title: export_doc_title(title),
                                                              display_url: export_url)
    when 'pdf'
      response['Content-Type'] = 'application/pdf'
      response['Content-Disposition'] = doc_export_attachment(slug, doc_id, 'pdf')
      ExportPdfRenderer.render(
        export_html_bundle(exporter.html_entries_for_doc(doc_id), title: export_doc_title(title),
                                                                  pdf_export: true,
                                                                  display_url: export_url),
        display_url: export_url,
        title: export_doc_title(title),
        logo_data_uri: export_logo_data_uri,
        export_date: Time.now.utc.strftime('%Y-%m-%d')
      )
    else
      response['Content-Type'] = 'text/markdown; charset=utf-8'
      response['Content-Disposition'] = doc_export_attachment(slug, doc_id, 'md')
      exporter.export_markdown_doc(doc_id)
    end
  end

  def export_doc_title(doc_title)
    "#{@manifest.export_title} — #{doc_title}"
  end

  def export_html_bundle(entries, title:, display_url: nil, pdf_export: false)
    ExportHtmlRenderer.render(
      title: title,
      generated_at: Time.now.utc.strftime('%Y-%m-%d %H:%M UTC'),
      entries: entries,
      print_css: ExportPrintCss.load,
      logo_data_uri: export_logo_data_uri,
      pdf_export: pdf_export,
      export_date: Time.now.utc.strftime('%Y-%m-%d')
    )
  end

  def export_html_document(exporter, pdf_export: false)
    export_html_bundle(exporter.html_entries, title: @manifest.export_title, pdf_export: pdf_export,
                                              display_url: '')
  end

  def export_logo_data_uri
    path = File.expand_path('../public/logo.png', __dir__)
    return '' unless File.file?(path)

    "data:image/png;base64,#{Base64.strict_encode64(File.read(path, mode: 'rb'))}"
  end

  def export_format_param(value)
    %w[md html pdf].include?(value.to_s.downcase) ? value.to_s.downcase : 'md'
  end

  def export_scope_param(value, project_root)
    scope = value.to_s.strip
    scope = 'full' if scope.empty?
    registry = ExportTagRegistry.for_project(project_root)
    return 'full' if scope == 'full'
    return scope if registry.known?(scope)

    'full'
  end

  def export_attachment(slug, ext, scope: 'full')
    suffix = scope == 'full' ? '' : "-#{scope}"
    %(attachment; filename="#{@manifest.export_basename}#{suffix}.#{ext}")
  end

  def doc_export_attachment(slug, doc_id, ext)
    %(attachment; filename="#{@manifest.export_basename}-#{doc_id}.#{ext}")
  end

  def set_doc_export_nav(slug, doc)
    @doc_export = {
      'doc_id' => doc['doc_id'],
      'title' => doc['title'] || doc['doc_id'],
      'action' => "/projects/#{slug}/docs/#{doc['doc_id']}/export"
    }
  end

  def download_annex(r, project_root, annex_id)
    annex_store = AnnexStore.new(project_root)
    version = r.params['version'].to_s.strip
    file = if version != '' && version.to_i.positive?
             annex_store.file_for_version(annex_id, version.to_i)
           else
             annex_store.latest_file(annex_id)
           end
    http_error!(404) unless file
    path = File.join(project_root, 'annexes', 'files', file['filename'])
    http_error!(404) unless File.file?(path)
    entry = annex_store.find(annex_id)
    slug = entry ? entry['slug'].to_s : "annex-#{annex_id}"
    download_name = AnnexAssetName.download_filename(slug: slug, stored_filename: file['filename'])
    response['Content-Type'] = annex_content_type(file['filename'])
    response['Content-Disposition'] = %(inline; filename="#{download_name}")
    File.binread(path)
  end

  def annex_content_type(filename)
    ext = File.extname(filename.to_s).delete_prefix('.').downcase
    ExportAnnexAssets::MIME_TYPES.fetch(ext, 'application/octet-stream')
  end

  def routes_doc(r, slug, project_root, doc_id)
    doc = resolve_doc(@manifest, doc_id)
    http_error!(404) unless doc

    @doc = doc
    @doc_path = doc['path']
    kind = doc['kind']

    r.on('rows', String) do |row_id|
      http_error!(404) unless kind == 'table'

      routes_table_row(r, slug, doc_id, row_id)
    end

    r.on('fullscreen') do
      http_error!(404) unless kind == 'table'

      r.get { render_table_fullscreen(slug) }
      r.post { save_table_fullscreen(r, slug, doc_id) }
    end

    r.on('presence') do
      r.post { document_presence_heartbeat(r, slug, doc_id) }
      r.post('leave') { document_presence_leave(r, slug, doc_id) }
    end

    r.get('export') { render_document_export(r, slug, project_root, doc_id) }

    r.get { render_doc(r, kind, slug, project_root) }
    r.post('rows') { handle_table_rows(r, slug, doc_id) }
    r.post('annex') { upload_annex(r, slug, project_root, doc_id) }
    r.post { save_doc_or_annex(r, slug, project_root, doc_id, kind) }
  end

  def routes_table_row(r, slug, doc_id, row_id)
    store = TableDocumentStore.new(@store)
    @data = store.read(@doc_path)
    @row = store.find_row(@doc_path, row_id)
    http_error!(404) unless @row

    r.get do
      @content_class = 'max-w-3xl has-page-footer'
      @row_label = @row[@data[:schema]['primary_key']] || row_id
      @back_href = "/projects/#{slug}/docs/#{doc_id}"
      @back_label = t('table.back_to_table')
      doc_header(@data[:meta], @doc)
      view('docs/table_row')
    end
  end

  def render_table_fullscreen(_slug)
    @data = TableDocumentStore.new(@store).read(@doc_path)
    doc_header(@data[:meta], @doc)
    @back_href = "/projects/#{@slug}/docs/#{@doc['doc_id']}"
    @back_label = t('table.back_to_table')
    view('docs/table_fullscreen', layout: 'layouts/table_fullscreen')
  end

  def save_table_fullscreen(r, slug, doc_id)
    changes = r.params['document_changes'].to_s.strip
    http_error!(400, detail_key: 'errors.details.changes_required') if changes.empty?

    meta = doc_meta(slug, @doc_path)
    version = SemverBump.next_version(meta.dig('iso27001', 'version'),
                                      significant: r.params['significant_change'] == '1')
    date = Time.now.utc.strftime('%Y-%m-%d')
    rows_params = r.params['rows'] || {}

    TableDocumentStore.new(@store).save_fullscreen(
      @doc_path,
      rows_params: rows_params,
      version: version,
      date: date,
      author: author_name,
      changes: changes
    )
    commit_and_redirect!(r, "/projects/#{slug}/docs/#{doc_id}/fullscreen",
                         commit_message: "#{doc_id} v#{version}: #{changes}",
                         toast_key: 'toast.table_saved',
                         significant: r.params['significant_change'] == '1')
  rescue TableDocumentStore::ValidationError => e
    flash_error(e.message)
    r.redirect("/projects/#{slug}/docs/#{doc_id}/fullscreen")
  end

  def table_redirect_path(slug, doc_id, r, row_id: nil)
    if r.params['return_to'] == 'fullscreen'
      "/projects/#{slug}/docs/#{doc_id}/fullscreen"
    elsif row_id
      "/projects/#{slug}/docs/#{doc_id}/rows/#{row_id}"
    else
      "/projects/#{slug}/docs/#{doc_id}"
    end
  end

  def render_doc(r, kind, slug, project_root)
    case kind
    when 'text'
      @data = TextDocumentStore.new(@store).read(@doc_path)
      @content_class = 'max-w-3xl has-page-footer'
      doc_header(@data[:meta], @doc)
      set_doc_export_nav(slug, @doc)
      view('docs/text')
    when 'table'
      @data = TableDocumentStore.new(@store).read(@doc_path)
      @content_class = 'max-w-[96rem] has-page-footer'
      doc_header(@data[:meta], @doc)
      set_doc_export_nav(slug, @doc)
      view('docs/table')
    when 'file_annex'
      meta = doc_meta(slug, @doc_path)
      raw = @store.read(OkfPaths.md(@doc_path))
      _parsed_meta, @annex_body = FrontMatter.parse(raw)
      annex_store = AnnexStore.new(project_root)
      aid = meta.dig('iso27001', 'annex_id')
      if aid.to_s.strip.empty?
        entry = annex_store.find_by_slug(@doc['doc_id'])
        aid = entry['id'] if entry
      end
      @annex_id = aid
      @annex_versions = aid ? annex_store.versions(aid) : []
      @latest_annex_file = aid ? annex_store.latest_file(aid) : nil
      @annex_file_by_doc_version = @annex_versions.each_with_object({}) do |version, map|
        doc_version = version['document_version']
        map[doc_version] = version if doc_version
      end
      @version_control_rows = VersionControlWriter.sorted_rows(@annex_body)
      @version_links = @annex_file_by_doc_version.each_with_object({}) do |(_doc_ver, file_ver), links|
        links[file_ver['document_version']] =
          "/projects/#{slug}/annexes/#{@annex_id}?version=#{file_ver['version']}"
      end
      @asset_kind = AnnexAssetKind.resolve(@doc, @annex_versions)
      @export_tag_registry = ExportTagRegistry.for_project(project_root)
      @export_tag_options = @export_tag_registry.tags_for('asset')
      @doc_export_tags = DocumentExportTags.for_doc(@doc, store: @store, manifest: @manifest)
      @annex_excluded = AnnexStatus.excluded?(@doc)
      @annex_referenced_in = AnnexReferenceIndex.new(@manifest, store: @store).referencing_entries(@doc['doc_id'])
      @annex_permalink = "#{r.base_url}/projects/#{slug}/docs/#{@doc['doc_id']}"
      @annex_bbcode = "[ANNEX #{@doc['doc_id']}]"
      @back_href = "/projects/#{slug}/annexes"
      @back_label = t('annexes.folder_label')
      @content_class = 'max-w-3xl has-page-footer'
      doc_header(meta, @doc)
      set_doc_export_nav(slug, @doc)
      view('docs/annex')
    else
      http_error!(404)
    end
  end

  def save_doc_or_annex(r, slug, project_root, doc_id, kind)
    if kind == 'file_annex'
      return upload_annex(r, slug, project_root, doc_id) if upload_param_file(r)

      if r.params['_method'] == 'delete'
        exclude_annex_from_export(r, slug, doc_id)
      elsif r.params['_method'] == 'patch' && r.params['restore'] == '1'
        restore_annex_to_export(r, slug, doc_id)
      else
        save_annex_metadata(r, slug, doc_id)
      end
    else
      save_document(r, slug, doc_id, kind)
    end
  end

  def exclude_annex_from_export(r, slug, doc_id)
    http_error!(400, detail_key: 'errors.details.annex_already_excluded') if AnnexStatus.excluded?(@doc)

    changes = r.params['document_changes'].to_s.strip
    http_error!(400, detail_key: 'errors.details.changes_required') if changes.empty?

    record_annex_lifecycle_change(slug, doc_id, changes: changes)
    @manifest.soft_delete_annex!(doc_id)
    commit_and_redirect!(r, "/projects/#{slug}/docs/#{doc_id}",
                         commit_message: "#{doc_id}: excluded from export",
                         toast_key: 'toast.annex_excluded',
                         significant: false)
  end

  def restore_annex_to_export(r, slug, doc_id)
    http_error!(400, detail_key: 'errors.details.annex_not_excluded') unless AnnexStatus.excluded?(@doc)

    changes = r.params['document_changes'].to_s.strip
    http_error!(400, detail_key: 'errors.details.changes_required') if changes.empty?

    record_annex_lifecycle_change(slug, doc_id, changes: changes)
    @manifest.restore_annex!(doc_id)
    commit_and_redirect!(r, "/projects/#{slug}/docs/#{doc_id}",
                         commit_message: "#{doc_id}: restored to export",
                         toast_key: 'toast.annex_restored',
                         significant: false)
  end

  def record_annex_lifecycle_change(slug, _doc_id, changes:)
    meta = doc_meta(slug, @doc_path)
    version = SemverBump.next_version(meta.dig('iso27001', 'version'), significant: false)
    date = Time.now.utc.strftime('%Y-%m-%d')
    title = @doc['title'].to_s.strip
    title = meta['title'].to_s.strip if title.empty?
    description = meta['description'].to_s.strip
    AnnexDocumentStore.new(@store).save_metadata(
      @doc_path,
      title: title,
      description: description,
      version: version,
      date: date,
      author: author_name,
      changes: changes,
      export_tags: nil
    )
  end

  def save_annex_metadata(r, slug, doc_id)
    title = r.params['title'].to_s.strip
    description = r.params['description'].to_s.strip
    changes = r.params['document_changes'].to_s.strip
    http_error!(400, detail_key: 'errors.details.title_required') if title.empty?
    http_error!(400, detail_key: 'errors.details.changes_required') if changes.empty?

    meta = doc_meta(slug, @doc_path)
    version = SemverBump.next_version(meta.dig('iso27001', 'version'),
                                      significant: r.params['significant_change'] == '1')
    date = Time.now.utc.strftime('%Y-%m-%d')
    registry = ExportTagRegistry.for_project(File.join(DATA_PATH, 'projects', slug))
    export_tags = ExportTagsParam.normalize(r.params['export_tags'], registry: registry)
    AnnexDocumentStore.new(@store).save_metadata(
      @doc_path,
      title: title,
      description: description,
      version: version,
      date: date,
      author: author_name,
      changes: changes,
      export_tags: export_tags
    )
    @manifest.update_annex!(doc_id, 'title' => title, 'description' => description)
    commit_and_redirect!(r, "/projects/#{slug}/docs/#{doc_id}",
                         commit_message: "#{doc_id} v#{version}: #{changes}",
                         toast_key: 'toast.annex_saved',
                         significant: r.params['significant_change'] == '1')
  end

  def handle_table_rows(r, slug, doc_id)
    store = TableDocumentStore.new(@store)
    row_id = r.params['row_id'].to_s
    if row_id != '' && r.params['_method'] == 'delete'
      store.soft_delete(@doc_path, row_id)
      commit_and_redirect!(r, table_redirect_path(slug, doc_id, r),
                           commit_message: "#{doc_id}: table row",
                           toast_key: 'toast.row_deleted',
                           significant: false)
    elsif row_id != '' && r.params['_method'] == 'patch'
      store.update_row(@doc_path, row_id, r.params)
      commit_and_redirect!(r, table_redirect_path(slug, doc_id, r, row_id: row_id),
                           commit_message: "#{doc_id}: table row",
                           toast_key: 'toast.row_updated',
                           significant: false)
    else
      row = store.add_row(@doc_path, r.params)
      commit_and_redirect!(r, table_redirect_path(slug, doc_id, r, row_id: row['_row_id']),
                           commit_message: "#{doc_id}: table row",
                           toast_key: 'toast.row_added',
                           significant: false)
    end
  rescue TableDocumentStore::ValidationError => e
    flash_error(e.message)
    if row_id != '' && r.params['_method'] == 'patch'
      r.redirect("/projects/#{slug}/docs/#{doc_id}/rows/#{row_id}?edit=1")
    elsif r.params['return_to'] == 'fullscreen'
      r.redirect("/projects/#{slug}/docs/#{doc_id}/fullscreen")
    else
      r.redirect("/projects/#{slug}/docs/#{doc_id}")
    end
  end

  def upload_annex(r, slug, project_root, doc_id)
    annex_store = AnnexStore.new(project_root)
    doc_store = AnnexDocumentStore.new(@store)
    meta = doc_meta(slug, @doc_path)
    http_error!(400, detail_key: 'errors.details.annex_excluded') if AnnexStatus.excluded?(@doc)

    file = r.params['file']
    tempfile = upload_param_file(r)
    http_error!(400, detail_key: 'errors.details.file_required') unless file && tempfile

    aid = meta.dig('iso27001', 'annex_id')
    unless aid
      title = annex_title_for_upload(r)
      aid = annex_store.create_annex(title: title, slug: doc_id)
      doc_store.set_annex_id(@doc_path, aid, author: author_name)
      meta = doc_meta(slug, @doc_path)
    end

    original_name = upload_param_filename(file)
    changes = r.params['document_changes'].to_s.strip
    changes = IsooI18n.t('annex.upload_changes') if changes.empty?

    version = SemverBump.next_version(meta.dig('iso27001', 'version'),
                                      significant: r.params['significant_change'] == '1')
    date = Time.now.utc.strftime('%Y-%m-%d')
    title = @doc['title'].to_s.strip
    title = meta['title'].to_s.strip if title.empty?
    title = doc_id if title.empty?

    annex_store.upload(
      annex_id: aid,
      uploaded_file: tempfile.read,
      original_name: original_name,
      document_version: version
    )
    asset_kind = AnnexAssetKind.from_filename(original_name)
    @manifest.update_annex!(doc_id, 'asset_kind' => asset_kind)

    doc_store.save_metadata(
      @doc_path,
      title: title,
      description: meta['description'].to_s,
      version: version,
      date: date,
      author: author_name,
      changes: changes
    )

    bump_project_version!(significant: r.params['significant_change'] == '1')

    self.class.git.commit("annex #{aid} upload")
    flash_success('toast.file_uploaded')
    r.redirect("/projects/#{slug}/docs/#{doc_id}")
  end

  def upload_param_file(r)
    file = r.params['file']
    return nil unless file.is_a?(Hash)

    file[:tempfile] || file['tempfile']
  end

  def upload_param_filename(file)
    name = file[:filename] || file['filename']
    name = name.to_s.strip
    name.empty? ? 'file' : name
  end

  def annex_title_for_upload(r)
    title = r.params['title'].to_s.strip
    title = @doc['title'].to_s.strip if title.empty?
    title = @doc['doc_id'].to_s if title.empty?
    title
  end

  def annex_versions_for(slug, doc)
    meta = doc_meta(slug, doc['path'])
    aid = meta.dig('iso27001', 'annex_id')
    return [] unless aid

    AnnexStore.new(File.join(DATA_PATH, 'projects', slug)).versions(aid)
  rescue StandardError
    []
  end

  def save_document(r, slug, doc_id, kind)
    significant = r.params['significant_change'] == '1'
    changes = r.params['document_changes'].to_s.strip
    http_error!(400, detail_key: 'errors.details.changes_required') if changes.empty?

    update_response_title!(doc_id, r.params['document_title']) if r.params.key?('document_title')

    meta = doc_meta(slug, @doc_path)
    version = SemverBump.next_version(meta.dig('iso27001', 'version'), significant: significant)
    date = Time.now.utc.strftime('%Y-%m-%d')

    case kind
    when 'text'
      TextDocumentStore.new(@store).save(@doc_path, fields: r.params, version: version,
                                                    date: date, author: author_name, changes: changes)
    when 'table'
      rows = TableDocumentStore.new(@store).read(@doc_path)[:rows]
      TableDocumentStore.new(@store).save_rows(@doc_path, rows: rows, version: version,
                                                          date: date, author: author_name, changes: changes)
    end

    commit_and_redirect!(r, "/projects/#{slug}/docs/#{doc_id}",
                         commit_message: "#{doc_id} v#{version}: #{changes}",
                         toast_key: kind == 'table' ? 'toast.table_saved' : 'toast.document_saved',
                         significant: significant)
  end

  def document_presence_heartbeat(_r, slug, doc_id)
    presence = DocumentPresence.new
    presence.heartbeat(slug: slug, doc_id: doc_id, editor_id: presence_editor_id, name: author_name)
    others = presence.others(slug: slug, doc_id: doc_id, editor_id: presence_editor_id)
    response['Content-Type'] = 'application/json'
    JSON.generate(
      editors: others,
      poll_interval: DocumentPresence::POLL_INTERVAL,
      backend: presence.backend
    )
  end

  def document_presence_leave(_r, slug, doc_id)
    DocumentPresence.new.leave(slug: slug, doc_id: doc_id, editor_id: presence_editor_id)
    response.status = 204
    ''
  end

  def update_response_title!(doc_id, title)
    title = title.to_s.strip
    return if title.empty?

    _form, response = @manifest.find_response(doc_id)
    return unless response

    response['title'] = title
    @manifest.save!
    @doc = @doc.merge('title' => title) if @doc && @doc['doc_id'] == doc_id
    @header_title = title
  end

  def template_id_for(manifest)
    id = manifest.data['id'].to_s.strip
    id.empty? ? Container.template_id : id
  end
end
