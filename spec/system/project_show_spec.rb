# frozen_string_literal: true

require_relative '../spec_helper'
require 'fileutils'
require 'securerandom'

RSpec.describe 'project show', type: :request do
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
end
