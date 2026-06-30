# frozen_string_literal: true

require 'yaml'
require 'time'
require 'date'

module FrontMatter
  module_function

  def parse(text)
    return [{}, text] unless text.start_with?("---\n")

    parts = text.split("---\n", 3)
    return [{}, text] if parts.length < 3

    meta = parse_yaml(parts[1])
    [meta || {}, parts[2]]
  end

  def parse_yaml(yaml)
    fixed = yaml.lines.map { |line| fix_yaml_line(line) }.join
    YAML.safe_load(fixed, permitted_classes: [Time, Date], aliases: true)
  rescue Psych::SyntaxError
    YAML.safe_load(fixed)
  end

  def fix_yaml_line(line)
    return line unless line.start_with?('description: ')

    value = line.sub('description: ', '').strip
    return line if value.start_with?('"', "'")
    return line unless value.include?(':')

    "description: #{value.inspect}\n"
  end
  module_function :fix_yaml_line

  def dump(meta, body)
    yaml = meta.to_yaml.sub(/\A---\n/, '')
    "---\n#{yaml}---\n\n#{body}"
  end
end
