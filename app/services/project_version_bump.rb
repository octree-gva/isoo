# frozen_string_literal: true

module ProjectVersionBump
  module_function

  DEFAULT = '0.0.0'
  SEMVER = /\A\d+\.\d+\.\d+\z/

  def normalize_version(current)
    return DEFAULT if current.nil?

    text = current.to_s.strip
    return DEFAULT if text.empty?
    return text if text.match?(SEMVER)

    # Unquoted YAML can load 0.0.2 as Float 0.02.
    if current.is_a?(Float) && current.positive? && current < 1
      patch = (current * 100).round
      return format_version(0, 0, patch)
    end

    if current.is_a?(Integer) || text.match?(/\A\d+\z/)
      return format_version(0, 0, current.is_a?(Integer) ? current : text.to_i)
    end

    parts = text.split('.').map(&:to_i)
    case parts.length
    when 2 then format_version(0, parts[0], parts[1])
    when 3 then format_version(parts[0], parts[1], parts[2])
    else DEFAULT
    end
  end

  def next_version(current, significant:)
    major, minor, patch = parse(normalize_version(current))

    if significant
      minor += 1
      patch = 0
      if minor >= 10
        major += 1
        minor = 0
      end
    elsif patch >= 9
      minor += 1
      patch = 0
      if minor >= 10
        major += 1
        minor = 0
      end
    else
      patch += 1
    end

    format_version(major, minor, patch)
  end

  def parse(current)
    normalize_version(current).split('.').map(&:to_i).first(3)
  end

  def format_version(major, minor, patch)
    "#{major}.#{minor}.#{patch}"
  end
  private_class_method :parse
end
