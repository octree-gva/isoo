# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'

RSpec.describe AnnexCreator do
  it 'creates a new annex manifest entry and files' do
    Dir.mktmpdir do |tmp|
      slug = 'test-annex'
      project_root = File.join(tmp, 'projects', slug)
      FileUtils.mkdir_p(project_root)
      File.write(File.join(project_root, 'manifest.yaml'), { 'name' => 'Test', 'annexes' => [] }.to_yaml)

      doc_id = AnnexCreator.new(data_root: tmp).create(project_slug: slug, author: 'tester', title: 'My diagram')

      manifest = ProjectManifest.load(project_root)
      annex = manifest.find_annex(doc_id)
      expect(annex['title']).to eq('My diagram')
      expect(File.file?(File.join(project_root, annex['path'], "#{doc_id}.md"))).to be true
    end
  end
end
