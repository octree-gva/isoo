# frozen_string_literal: true

module SemverBump
  module_function

  def next_version(current, significant:)
    parts = current.to_s.split('.').map(&:to_i)
    parts = [0, 1, 0] if parts.length < 3

    major = parts[0]
    minor = parts[1]
    patch = parts[2]
    numeric = (major * 10_000) + (minor * 100) + patch

    if significant
      return '1.0.0' if numeric >= 11_00 # past 0.10.10

      return "#{major + 1}.0.0"
    end

    "#{major}.#{minor + 1}.0"
  end
end
