# frozen_string_literal: true

class AnnexAssetKind
  IMAGE_EXTENSIONS = %w[png jpg jpeg gif webp svg].freeze

  def self.from_filename(filename)
    ext = File.extname(filename.to_s).delete_prefix('.').downcase
    IMAGE_EXTENSIONS.include?(ext) ? 'image' : 'document'
  end

  def self.resolve(doc, versions)
    kind = doc['asset_kind'].to_s.strip
    return kind if %w[image document].include?(kind)

    latest = versions.last
    return 'document' unless latest

    from_filename(latest['filename'])
  end
end
