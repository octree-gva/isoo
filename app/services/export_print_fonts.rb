# frozen_string_literal: true

require 'base64'

module ExportPrintFonts
  FONT_DIR = File.expand_path('../../public/fonts', __dir__)

  WEIGHTS = {
    400 => 'Regular',
    500 => 'Medium',
    600 => 'SemiBold',
    700 => 'Bold'
  }.freeze

  module_function

  def css
    @css ||= build_css
  end

  def build_css
    WEIGHTS.filter_map do |weight, suffix|
      path = File.join(FONT_DIR, "IBMPlexSans-#{suffix}.ttf")
      next unless File.file?(path)

      data = Base64.strict_encode64(File.read(path, mode: 'rb'))
      <<~CSS.strip
        @font-face {
          font-family: "IBM Plex Sans";
          src: url("data:font/ttf;base64,#{data}") format("truetype");
          font-weight: #{weight};
          font-style: normal;
          font-display: swap;
        }
      CSS
    end.join("\n")
  end
end
