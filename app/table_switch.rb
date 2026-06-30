# frozen_string_literal: true

module TableSwitch
  module_function

  def on?(value, col = nil)
    str = value.to_s.strip
    if str.empty?
      default = col&.fetch('default', false)
      return true if default == true
      return false if default == false

      return %w[1 true yes on].include?(default.to_s.downcase)
    end
    %w[1 true yes on].include?(str.downcase)
  end
end
