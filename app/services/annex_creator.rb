# frozen_string_literal: true

require 'fileutils'
require 'yaml'

require_relative '../i18n'

class AnnexCreator
  def initialize(data_root:, git: nil)
    @data_root = data_root
    @git = git
  end

  def create(project_slug:, author: 'system', title: nil, asset_kind: 'document')
    project_root = File.join(@data_root, 'projects', project_slug)
    manifest = ProjectManifest.load(project_root)
    number = manifest.next_annex_number
    doc_id = "annex-#{number}"
    title = title.to_s.strip
    title = IsooI18n.t('annex.default_title', number: number) if title.empty?
    path = "annexes/#{doc_id}"
    entry = {
      'doc_id' => doc_id,
      'path' => path,
      'title' => title,
      'kind' => ProjectManifest::FILE_ANNEX_KIND,
      'asset_kind' => asset_kind
    }
    write_annex_files(project_root, entry, author)
    manifest.add_annex!(entry)
    @git&.commit("#{doc_id}: create annex")
    doc_id
  end

  private

  def write_annex_files(project_root, entry, _author)
    dest_dir = File.join(project_root, entry['path'])
    FileUtils.mkdir_p(dest_dir)
    doc_id = entry['doc_id']
    version = '0.1.0'

    schema = {
      'schema_version' => '1',
      'kind' => ProjectManifest::FILE_ANNEX_KIND,
      'asset_kind' => entry['asset_kind'],
      'description' => ''
    }
    File.write(File.join(dest_dir, "#{doc_id}.schema.yaml"), schema.to_yaml)

    meta = {
      'type' => 'ISO27001 Annex',
      'title' => entry['title'],
      'description' => '',
      'okf_version' => '0.1',
      'tags' => %w[iso27001 annex],
      'timestamp' => Time.now.utc.iso8601,
      'iso27001' => {
        'doc_id' => doc_id,
        'version' => version,
        'kind' => ProjectManifest::FILE_ANNEX_KIND,
        'classification' => 'Confidential',
        'schema' => "#{doc_id}.schema.yaml",
        'annex_id' => nil
      },
      'resource' => nil
    }
    body = IsooI18n.t('annex.upload_body', title: entry['title'])
    File.write(File.join(dest_dir, "#{doc_id}.md"), FrontMatter.dump(meta, body), encoding: 'UTF-8')
  end
end
