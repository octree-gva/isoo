# frozen_string_literal: true

require 'cgi'

module JsonAttr
  module_function

  def encode(value)
    CGI.escapeHTML(value.to_json)
  end
end
