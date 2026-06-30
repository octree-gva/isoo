# frozen_string_literal: true

class IsooHttpError < StandardError
  attr_reader :status, :detail

  def initialize(status, detail: nil, detail_key: nil, **i18n_opts)
    @status = status.to_i
    @detail = detail || (detail_key ? IsooI18n.t(detail_key, **i18n_opts) : nil)
    super(@detail || IsooI18n.t("errors.#{@status}.title"))
  end
end
