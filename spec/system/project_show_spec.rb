# frozen_string_literal: true

require_relative '../spec_helper'
require 'fileutils'
require 'securerandom'

RSpec.describe 'project show', type: :request do
  def set_doc_owner!(slug, doc_path, email:)
    store = FileStore.new(File.join(App::DATA_PATH, 'projects', slug))
    md = OkfPaths.md(doc_path)
    meta, body = FrontMatter.parse(store.read(md))
    DocumentOwner.write_to_meta!(meta, { 'owner_name' => 'Owner', 'owner_email' => email })
    store.write(md, FrontMatter.dump(meta, body))
  end

  it 'renders an empty project dashboard without error' do
    slug = "empty-#{SecureRandom.hex(3)}"
    root = File.join(App::DATA_PATH, 'projects', slug)
    FileUtils.mkdir_p(root)
    File.write(File.join(root, 'manifest.yaml'), {
      'name' => 'Empty Project',
      'documents' => [],
      'forms' => nil
    }.to_yaml)

    expect_get_page!("/projects/#{slug}", 'empty project dashboard',
                     include_markers: ['Empty Project', 'Annexes', "/projects/#{slug}/annexes"],
                     exclude_markers: ['id="project-documents-empty"'])
  end

  it 'shows an owner badge when the document owner is the current user' do
    slug = create_test_project!(name: 'Owner Badge')
    set_doc_owner!(slug, 'context/organisation-overview', email: 'dev@local')

    expect_get_page!("/projects/#{slug}", 'dashboard with owner badge',
                     include_markers: ['badge badge-primary', '>owner</span>'])

    set_doc_owner!(slug, 'context/organisation-overview', email: 'owner@example.com')

    expect_get_page!("/projects/#{slug}", 'dashboard without owner badge',
                     exclude_markers: ['badge badge-primary'])
  end
end
