# frozen_string_literal: true

require_relative '../spec_helper'
require 'stringio'

RSpec.describe 'managing annex assets', type: :request do
  let(:slug) { create_test_project!(name: 'Asset Management Co') }
  let(:annex_doc_id) { 'architectural-schema' }

  before { seed_test_annexes!(slug) }

  it 'uploads annex file without document_changes and records version history' do
    png_bytes = "\x89PNG\r\n\x1a\nfake"
    file = Rack::Test::UploadedFile.new(StringIO.new(png_bytes), 'image/png', original_filename: 'diagram.png')
    post "/projects/#{slug}/docs/#{annex_doc_id}/annex", file: file
    expect(last_response.status).to eq(302)

    follow_redirect_and_expect_page!('annex after upload without changes',
                                     include_markers: [
                                       'annex-current-heading',
                                       annex_doc_id,
                                       'Document Version Control',
                                       'Uploaded new asset version'
                                     ],
                                     exclude_markers: ['diagram.png'])
  end

  it 'uploads to a newly created annex without document_changes' do
    post "/projects/#{slug}/annexes"
    follow_redirect!
    file = Rack::Test::UploadedFile.new(StringIO.new('new'), 'text/plain', original_filename: 'policy.pdf')
    post "/projects/#{slug}/docs/annex-1/annex", file: file
    expect(last_response.status).to eq(302)
    follow_redirect_and_expect_page!('new annex after upload',
                                     include_markers: ['annex-1', 'Uploaded new asset version'],
                                     exclude_markers: ['policy.pdf'])
  end

  it 'accepts file upload on the metadata route when multipart posts omit /annex' do
    png_bytes = "\x89PNG\r\n\x1a\nfake"
    file = Rack::Test::UploadedFile.new(StringIO.new(png_bytes), 'image/png', original_filename: 'fallback.png')
    post "/projects/#{slug}/docs/#{annex_doc_id}", file: file
    expect(last_response.status).to eq(302)
    follow_redirect_and_expect_page!('annex after fallback upload',
                                     include_markers: [annex_doc_id, 'Uploaded new asset version'],
                                     exclude_markers: ['fallback.png'])
  end

  it 'browses annex pages, uploads a file, and serves it for download' do
    expect_get_page!("/projects/#{slug}", 'project dashboard',
                     include_markers: ['Asset Management Co', 'Annexes', "/projects/#{slug}/annexes"])

    expect_get_page!("/projects/#{slug}/annexes", 'annexes folder',
                     include_markers: [
                       'annexes-slots',
                       'architectural-schema',
                       'network-diagram',
                       "/projects/#{slug}/docs/#{annex_doc_id}",
                       'image',
                       'New annex'
                     ])

    expect_get_page!("/projects/#{slug}/docs/#{annex_doc_id}", 'seeded annex',
                     include_markers: [
                       'Architectural schema',
                       'annex-share-heading',
                       'annex-upload-form',
                       "/projects/#{slug}/docs/#{annex_doc_id}",
                       "[ANNEX #{annex_doc_id}]",
                       'upload_annex_modal',
                       'annex-metadata-form',
                       'Export tags',
                       'annex-current-heading',
                       annex_doc_id,
                       'data-dialog-open="upload_annex_modal"',
                       'data-wizard-open="save_annex_metadata_modal"'
                     ])

    png_bytes = "\x89PNG\r\n\x1a\nfake-image-bytes"
    file = Rack::Test::UploadedFile.new(StringIO.new(png_bytes), 'image/png', original_filename: 'schema.png')
    post "/projects/#{slug}/docs/#{annex_doc_id}/annex",
         file: file, document_changes: 'Uploaded architectural schema diagram'
    expect(last_response.status).to eq(302)
    expect(last_response.headers['Location']).to eq("/projects/#{slug}/docs/#{annex_doc_id}")

    follow_redirect_and_expect_page!('annex after upload',
                                     include_markers: [
                                       'annex-current-heading',
                                       annex_doc_id,
                                       '/annexes/1?version=2',
                                       'image',
                                       'Document Version Control',
                                       'Uploaded architectural schema diagram'
                                     ],
                                     exclude_markers: ['schema.png'])

    project_root = File.join(App::DATA_PATH, 'projects', slug)
    annex_store = AnnexStore.new(project_root)
    latest = annex_store.latest_file(1)
    expect(latest).not_to be_nil
    expect(latest['original_name']).to eq('schema.png')
    expect(latest['document_version']).not_to be_nil

    get "/projects/#{slug}/annexes/1?version=2"
    expect(last_response.status).to eq(200)
    expect(last_response.body.b).to eq(png_bytes.b)
    expect(last_response.content_type).to include('image/png')
    expect(last_response.headers['Content-Disposition']).to include('filename="architectural-schema.png"')

    get "/projects/#{slug}/annexes/1"
    expect(last_response.status).to eq(200)
    expect(last_response.body.b).to eq(png_bytes.b)

    post "/projects/#{slug}/annexes"
    expect(last_response.status).to eq(302)
    follow_redirect!
    expect_rendered_page!(label: 'newly created annex',
                          include_markers: ['Annex details', 'annex-upload-form', 'annex-1'])
  end

  it 'excludes a seeded asset from exports and restores it' do
    root = File.join(App::DATA_PATH, 'projects', slug)
    post "/projects/#{slug}/docs/#{annex_doc_id}",
         _method: 'delete',
         document_changes: 'Placeholder seed diagram not needed for this audit pack'
    expect(last_response.status).to eq(302)
    follow_redirect_and_expect_page!('excluded annex',
                                     include_markers: ['deleted from exports', 'restore_annex_modal'])

    manifest = ProjectManifest.load(root)
    expect(AnnexStatus.excluded?(manifest.find_annex(annex_doc_id))).to be(true)

    exporter_ids = ProjectExporter.new(root, slug: slug).entries.map { |entry| entry.doc['doc_id'] }
    expect(exporter_ids).not_to include(annex_doc_id)

    post "/projects/#{slug}/docs/#{annex_doc_id}",
         _method: 'patch',
         restore: '1',
         document_changes: 'Needed again for export'
    expect(last_response.status).to eq(302)
    follow_redirect_and_expect_page!('restored annex',
                                     include_markers: %w[delete_annex_modal annex-upload-form],
                                     exclude_markers: ['restore_annex_modal'])

    exporter_ids = ProjectExporter.new(root, slug: slug).entries.map { |entry| entry.doc['doc_id'] }
    expect(exporter_ids).to include(annex_doc_id)
  end
end
