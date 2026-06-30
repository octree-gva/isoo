# frozen_string_literal: true

class ExportTagsParam
  def self.normalize(values, registry:)
    ids = Array(values).map(&:to_s).reject(&:empty?).uniq
    ids.select { |id| registry.known?(id) }.sort
  end
end
