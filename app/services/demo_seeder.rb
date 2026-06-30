# frozen_string_literal: true

require_relative '../i18n'

require 'fileutils'
require 'yaml'

class DemoSeeder
  MARKER = '.demo_seeded'

  TEXT_DOCS = {
    'context/organisation-overview' => {
      'about_us' => <<~TEXT.strip,
        Acme Open Source maintains ISOO and several public libraries. We are a remote-first
        team of twelve engineers across the EU.
      TEXT
      'our_products_and_services' => <<~TEXT.strip,
        - ISOO — ISO 27001 documentation manager (self-hosted)
        - Open-source CI integrations and security tooling
      TEXT
      'our_locations' => 'Headquarters: Berlin, Germany. Fully remote workforce.',
      'our_mission' => 'Make security compliance approachable for open source maintainers.',
      'our_values' => "- Transparency\n- Least privilege\n- Ship small, iterate often",
      'our_business_objectives' => <<~TEXT.strip
        - Achieve ISO 27001 certification by Q4
        - Reduce supplier onboarding time by 30%
      TEXT
    },
    'context/documented-isms-scope' => {
      'iso_27001_certification_scope_statement' => <<~TEXT.strip,
        The ISMS covers all production systems hosting customer documentation, the ISOO
        application, source repositories, and supporting cloud infrastructure.
      TEXT
      'scope_overview_internal_view' => 'Engineering, platform, and security operations teams.',
      'products_and_services' => 'ISOO SaaS, open-source libraries, professional services.',
      'locations' => 'Remote EU workforce; infrastructure in AWS eu-central-1.',
      'out_of_scope' => 'Contractors without signed NDAs; legacy marketing site.',
      'department_people' => 'Engineering (8), Platform (2), Security (2).',
      'in_scope' => 'GitHub org, AWS accounts, Hetzner backups, ISOO production cluster.',
      'technology' => 'Ruby, Python, PostgreSQL, S3, OIDC authentication.',
      'network' => 'TLS everywhere; private VPC; no on-premise network.'
    }
  }.freeze

  ANNEX_ASSETS = [
    {
      'doc_id' => 'architectural-schema',
      'path' => 'annexes/architectural-schema',
      'title' => 'Architectural schema',
      'description' => 'High-level diagram of applications, data stores, integrations, and trust ' \
                       'boundaries. Maintain it as systems evolve; link it to asset registers and network ' \
                       'diagrams. Auditors use it to understand scope and control placement.',
      'asset_kind' => 'image',
      'export_tags' => %w[soi],
      'upload_filename' => 'architectural-schema.png',
      'upload_changes' => 'Seeded placeholder architectural schema diagram'
    },
    {
      'doc_id' => 'network-diagram',
      'path' => 'annexes/network-diagram',
      'title' => 'Network diagram',
      'description' => 'Visual map of networks, subnets, firewalls, and key connectivity. Keep ' \
                       'it current after infrastructure changes. Supports network security policy reviews ' \
                       'and incident response.',
      'asset_kind' => 'image',
      'export_tags' => %w[soi],
      'upload_filename' => 'network-diagram.png',
      'upload_changes' => 'Seeded placeholder network diagram'
    }
  ].freeze

  MINIMAL_PNG = "\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR\x00\x00\x00\x01\x00\x00\x00\x01\x08\x02\x00\x00\x00\x90wS\xde" \
                "\x00\x00\x00\fIDATx\x9cc\xf8\x0f\x00\x01\x01\x01\x00\x18\xdd\x8d\xb4\x00\x00\x00\x00IEND\xaeB`\x82".b

  TABLE_ROWS = {
    'context/legal-and-contractual-requirements-register' => [
      {
        'standard' => 'GDPR',
        'requirement' => 'Lawful processing and data subject rights',
        'applicability' => 'All EU customer personal data',
        'required' => 'YES',
        'last_assessed_date' => '2026-01-15',
        'next_assessment_date' => '2027-01-15'
      },
      {
        'standard' => 'ISO 27001:2022',
        'requirement' => 'Establish and maintain an ISMS',
        'applicability' => 'Whole organisation',
        'required' => 'YES',
        'last_assessed_date' => '2026-02-01',
        'next_assessment_date' => '2027-02-01'
      }
    ],
    'registers/isms-risk-register' => [
      {
        'risk_status' => 'Open',
        'risk_treatment' => 'Mitigate',
        'risks_when_first_identified' => 'Compromise of production database credentials',
        'residual_risk' => 'Low — secrets in vault, rotation every 90 days'
      },
      {
        'risk_status' => 'Treated',
        'risk_treatment' => 'Accept',
        'risks_when_first_identified' => 'Delayed patching of non-critical dependencies',
        'residual_risk' => 'Low — automated Dependabot with SLA'
      }
    ],
    'context/physical-and-virtual-assets-register' => [
      {
        'asset_no' => 'SRV-001',
        'serial_no' => 'aws-i-0abc123',
        'asset_owner' => 'Platform team',
        'company_or_personal' => 'Company',
        'status' => 'In use',
        'description_of_asset' => 'ISOO production app (ECS)',
        'location_of_asset' => 'AWS eu-central-1',
        'importance' => 'High',
        'classification' => 'Confidential'
      },
      {
        'asset_no' => 'LAP-014',
        'serial_no' => 'C02XYZ',
        'asset_owner' => 'Engineering',
        'company_or_personal' => 'Company',
        'status' => 'In use',
        'description_of_asset' => 'Engineer workstation (FileVault)',
        'location_of_asset' => 'Remote — DE',
        'importance' => 'Medium',
        'classification' => 'Internal'
      }
    ],
    'context/data-asset-register-ropa' => [
      {
        'document' => '1',
        'identified_date' => '2026-01-10',
        'business_function_department_team' => 'Product',
        'where_is_it_where_is_the_information_being_stored_name_of_application' => 'CRM (SaaS)',
        'what_is_it_description_of_the_information_held' => 'Customer contact details and support history',
        'why_do_we_have_it_data_asset_purpose_of_the_processing' => 'Customer support and account management',
        'who_here_owns_it_information_owner' => 'Product lead'
      }
    ]
  }.freeze

  def initialize(data_root:, git: nil)
    @data_root = data_root
    @git = git
  end

  def populate(slug:, author:, force: false)
    root = project_root(slug)
    raise ArgumentError, "project missing: #{slug}" unless File.directory?(root)

    marker = File.join(root, MARKER)
    return :skipped if !force && File.file?(marker)

    store = ClassifiedFileStore.new(FileStore.new(root))
    seed_text_documents(store, author)
    seed_tables(store, author)
    seed_annex_assets(slug, author)
    populate_form_responses(slug, author)
    File.write(marker, { 'seeded_at' => Time.now.utc.iso8601, 'author' => author }.to_yaml)
    @git&.commit("seed: populate demo project #{slug}")
    :populated
  end

  def seed_annexes(slug:, author:)
    root = project_root(slug)
    raise ArgumentError, "project missing: #{slug}" unless File.directory?(root)

    seed_annex_assets(slug, author)
  end

  private

  def project_root(slug)
    File.join(@data_root, 'projects', slug)
  end

  def seed_text_documents(store, _author)
    TEXT_DOCS.each do |doc_path, fields|
      next unless store.exist?(OkfPaths.md(doc_path))

      TextDocumentStore.new(store).save(
        doc_path,
        fields: fields,
        record_version: false
      )
    end
  end

  def seed_tables(store, _author)
    TABLE_ROWS.each do |doc_path, rows|
      next unless store.exist?(OkfPaths.schema(doc_path))

      tds = TableDocumentStore.new(store)
      existing = tds.read(doc_path)[:rows]
      next if existing.any?

      rows.each { |row| tds.add_row(doc_path, row) }
    end
  end

  def populate_form_responses(slug, author)
    manifest = ProjectManifest.load(project_root(slug))
    creator = FormResponseCreator.new(data_root: @data_root, git: @git)
    manifest.forms.each do |form|
      next if form.fetch('responses', []).any?

      creator.create(project_slug: slug, form_id: form['doc_id'], author: author, record_version: false)
    end
  end

  def seed_annex_assets(slug, author)
    root = project_root(slug)
    manifest = ProjectManifest.load(root)
    store = ClassifiedFileStore.new(FileStore.new(root))
    annex_store = AnnexStore.new(root)
    doc_store = AnnexDocumentStore.new(store)

    ANNEX_ASSETS.each do |spec|
      next if manifest.find_annex(spec['doc_id'])

      create_seeded_annex(root, manifest, store, annex_store, doc_store, spec, author)
    end
  end

  def create_seeded_annex(_root, manifest, store, annex_store, doc_store, spec, author)
    doc_id = spec['doc_id']
    path = spec['path']
    version = '0.1.0'
    entry = {
      'doc_id' => doc_id,
      'path' => path,
      'title' => spec['title'],
      'kind' => ProjectManifest::FILE_ANNEX_KIND,
      'asset_kind' => spec['asset_kind'],
      'description' => spec['description']
    }

    write_seeded_annex_files(store, path, doc_id, spec, version, author)
    manifest.add_annex!(entry)

    aid = annex_store.create_annex(title: spec['title'], slug: doc_id)
    doc_store.set_annex_id(path, aid, author: author)
    annex_store.upload(
      annex_id: aid,
      uploaded_file: MINIMAL_PNG,
      original_name: spec['upload_filename'],
      document_version: version
    )

    doc_store.save_metadata(
      path,
      title: spec['title'],
      description: spec['description'],
      version: version,
      date: Time.now.utc.strftime('%Y-%m-%d'),
      author: author,
      changes: spec['upload_changes'],
      export_tags: spec['export_tags']
    )
    manifest.update_annex!(doc_id, 'asset_kind' => spec['asset_kind'])
  end

  def write_seeded_annex_files(store, path, doc_id, spec, version, author)
    schema = {
      'schema_version' => '1',
      'kind' => ProjectManifest::FILE_ANNEX_KIND,
      'asset_kind' => spec['asset_kind'],
      'annex_title' => spec['title'],
      'description' => spec['description'],
      'export_tags' => spec['export_tags']
    }
    schema_path = OkfPaths.schema(path)
    classification = 'Confidential'
    store.write(
      schema_path,
      schema.to_yaml,
      classification: classification,
      audit: annex_audit_fields(version, author, classification)
    )

    meta = {
      'type' => 'ISO27001 Annex',
      'title' => spec['title'],
      'description' => spec['description'],
      'okf_version' => '0.1',
      'tags' => %w[iso27001 annex],
      'timestamp' => Time.now.utc.iso8601,
      'iso27001' => {
        'doc_id' => doc_id,
        'version' => version,
        'kind' => ProjectManifest::FILE_ANNEX_KIND,
        'classification' => classification,
        'schema' => "#{doc_id}.schema.yaml",
        'annex_id' => nil
      },
      'resource' => nil
    }
    body = IsooI18n.t('annex.upload_body', title: spec['title'])
    store.write(
      OkfPaths.md(path),
      FrontMatter.dump(meta, body),
      classification: classification,
      audit: annex_audit_fields(version, author, classification)
    )
  end

  def annex_audit_fields(version, author, classification)
    {
      'classification' => classification,
      'version' => version,
      'modified_at' => Time.now.utc.iso8601,
      'modified_by' => author
    }
  end
end
