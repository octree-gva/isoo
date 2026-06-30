# frozen_string_literal: true

require_relative '../spec_helper'
require 'fileutils'
require 'tmpdir'

RSpec.describe ExportAnnexAssets do
  it 'embeds only the latest image annex version with doc id and document version in the caption' do
    Dir.mktmpdir do |tmp|
      files_dir = File.join(tmp, 'annexes', 'files')
      FileUtils.mkdir_p(files_dir)
      File.write(File.join(files_dir, '1-diagram-1.png'), 'oldpng')
      File.write(File.join(files_dir, '1-diagram-2.png'), 'newpng')
      File.write(File.join(tmp, 'annexes', 'registry.yaml'), {
        'next_id' => 2,
        'annexes' => [{ 'id' => 1, 'slug' => 'diagram', 'title' => 'Diagram' }]
      }.to_yaml)
      File.write(File.join(tmp, 'annexes', 'versions.yaml'), {
        'annexes' => {
          '1' => {
            'latest' => 2,
            'versions' => [
              {
                'version' => 1,
                'filename' => '1-diagram-1.png',
                'original_name' => 'network-old.png',
                'uploaded_at' => '2026-01-01T00:00:00Z',
                'document_version' => '0.1.0'
              },
              {
                'version' => 2,
                'filename' => '1-diagram-2.png',
                'original_name' => 'secret-upload-name.png',
                'uploaded_at' => '2026-01-02T00:00:00Z',
                'document_version' => '0.2.0'
              }
            ]
          }
        }
      }.to_yaml)

      html = described_class.new(tmp).html_for(1, doc_id: 'diagram', document_version: '0.2.0')

      expect(html.scan('class="export-annex-figure"').size).to eq(1)
      expect(html).to include('data:image/png;base64,')
      expect(html).to include('Version 0.2.0 — diagram')
      expect(html).not_to include('network-old.png')
      expect(html).not_to include('secret-upload-name.png')
      expect(html).not_to include('Version 0.1.0')
    end
  end
end
