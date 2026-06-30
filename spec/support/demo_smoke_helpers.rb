# frozen_string_literal: true

require 'securerandom'

module DemoSmokeHelpers
  def create_seeded_demo!(slug: nil, name: 'Demo Smoke Test')
    slug ||= "demo-smoke-#{SecureRandom.hex(3)}"
    data = App::DATA_PATH
    git = GitService.new(data)
    ProjectCreator.new(data_root: data, git: git).create(
      name: name, slug: slug, author: 'spec@isoo.local'
    )
    DemoSeeder.new(data_root: data, git: git).populate(
      slug: slug, author: 'spec@isoo.local', force: true
    )
    slug
  end

  def demo_manifest(slug)
    ProjectManifest.load(File.join(App::DATA_PATH, 'projects', slug))
  end

  def demo_store(slug)
    ClassifiedFileStore.new(FileStore.new(File.join(App::DATA_PATH, 'projects', slug)))
  end

  def expect_get_ok!(path, label, **page_opts)
    expect_get_page!(path, label, **page_opts)
  end

  def ensure_table_has_row!(slug, doc)
    store = demo_store(slug)
    tds = TableDocumentStore.new(store)
    data = tds.read(doc['path'])
    return if data[:rows].any?

    pk = data[:schema]['primary_key']
    tds.add_row(doc['path'], pk => '1')
  end

  def openable_demo_documents(manifest)
    manifest.documents
  end
end
