# frozen_string_literal: true

module AnnexStatus
  module_function

  def excluded?(annex)
    annex.is_a?(Hash) && annex['_deleted_at'].to_s != ''
  end

  def active?(annex)
    !excluded?(annex)
  end
end
