# frozen_string_literal: true

require_relative '../i18n'

class AnnexAssetName
  def self.label(doc_id:, document_version: nil, file_version: nil)
    version = document_version.to_s.strip
    version = file_version.to_s if version.empty?
    name = doc_id.to_s.strip
    name = 'annex' if name.empty?
    IsooI18n.t('export.assets.version_caption', version: version, name: name)
  end

  def self.download_filename(slug:, stored_filename:)
    ext = File.extname(stored_filename.to_s)
    base = slug.to_s.strip
    base = 'annex' if base.empty?
    "#{base}#{ext}"
  end
end
