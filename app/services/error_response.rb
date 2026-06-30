# frozen_string_literal: true

require 'tilt'
require 'cgi'

class ErrorResponse
  VIEWS_ROOT = File.expand_path('../views', __dir__)

  def self.render(status:, detail: nil)
    scope = view_scope(status, detail)
    layout = Tilt.new(File.join(VIEWS_ROOT, 'layouts/error.erb'))
    template = Tilt.new(File.join(VIEWS_ROOT, 'errors/show.erb'))
    layout.render(scope) { template.render(scope) }
  end

  def self.rack(status:, detail: nil)
    body = render(status: status, detail: detail)
    [
      status,
      {
        'content-type' => 'text/html; charset=utf-8',
        'content-length' => body.bytesize.to_s,
        'cache-control' => 'no-store'
      },
      [body]
    ]
  end

  def self.view_scope(status, detail)
    code = status.to_i
    Object.new.tap do |scope|
      scope.define_singleton_method(:t) { |key, **opts| IsooI18n.t(key, **opts) }
      scope.define_singleton_method(:escape_html) { |text| CGI.escapeHTML(text.to_s) }
      scope.instance_variable_set(:@error_status, code)
      scope.instance_variable_set(:@error_title, IsooI18n.t("errors.#{code}.title"))
      scope.instance_variable_set(:@error_message, IsooI18n.t("errors.#{code}.message"))
      scope.instance_variable_set(:@error_detail, detail)
    end
  end
  private_class_method :view_scope
end
