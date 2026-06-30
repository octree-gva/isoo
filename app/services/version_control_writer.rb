# frozen_string_literal: true

# Version history is stored in the markdown body on save (see +append_row+).
# Templates do not need a static version-control table; the UI and export render it dynamically.
module VersionControlWriter
  module_function

  HEADER = "# Document Version Control\n\n"
  TABLE_HEAD = "| Version | Last Modified | Last Modified By | Document Changes |\n" \
               "|---------|---------------|------------------|------------------|\n"

  def strip_block(body)
    return body unless body.include?(HEADER)

    _prefix, rest = body.split(HEADER, 2)
    return '' unless rest

    lines = rest.lines
    i = 0
    while i < lines.length
      line = lines[i]
      stripped = line.strip
      if stripped.empty?
        lookahead = ((i + 1)...lines.length).find { |j| !lines[j].strip.empty? }
        break if lookahead.nil?

        if i.zero? || lines[i - 1].match?(/^\s*\|/) || lines[lookahead].match?(/^\s*\|/)
          i += 1
          next
        end
        break
      elsif line.match?(/^\s*\|/)
        i += 1
      elsif line.match?(/^#+\s/)
        break
      else
        break
      end
    end
    lines[i..]&.join&.lstrip || ''
  end

  def append_row(body, version:, date:, author:, changes:, content: nil)
    content = strip_block(body) if content.nil?
    rows = sorted_rows(body).reject { |row| row['version'] == version.to_s }
    rows << row_hash(version, date, author, changes)
    rows.sort_by! { |row| semver_key(row['version']) }
    row_lines = rows.map { |row| format_row(row) }
    "#{HEADER}#{TABLE_HEAD}#{row_lines.join("\n")}\n\n#{content}"
  end

  def clear_history(body)
    "#{HEADER}#{TABLE_HEAD}#{strip_block(body)}"
  end

  def existing_rows(body)
    return [] unless body.include?(HEADER)

    block = body.split(HEADER, 2)[1]
    block.lines.select { |l| l.start_with?('|') && !l.include?('---') && !l.include?('Version |') }
  end

  def parse_row(line)
    cells = line.split('|').map(&:strip).reject(&:empty?)
    return nil if cells.length < 4

    {
      'version' => cells[0],
      'modified' => cells[1],
      'author' => cells[2],
      'changes' => cells[3]
    }
  end

  def sorted_rows(body)
    existing_rows(body).filter_map { |line| parse_row(line) }.sort_by { |row| semver_key(row['version']) }
  end

  def semver_key(version)
    parts = version.to_s.split('.').map(&:to_i)
    parts = [0, 1, 0] if parts.length < 3
    (parts[0] * 10_000) + (parts[1] * 100) + parts[2]
  end

  def row_hash(version, date, author, changes)
    {
      'version' => version.to_s,
      'modified' => date.to_s,
      'author' => author.to_s,
      'changes' => changes.to_s
    }
  end

  def format_row(row)
    "| #{row['version']} | #{row['modified']} | #{row['author']} | #{row['changes']} |"
  end
  private_class_method :row_hash, :format_row
end
