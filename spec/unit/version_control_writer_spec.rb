# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe VersionControlWriter do
  it 'appends version row' do
    body = described_class.append_row('', version: '0.2.0', date: '2026-01-01', author: 'a@b.c', changes: 'update')
    expect(body).to include('0.2.0')
    expect(body).to include('update')
    expect(body).to include('Document Version Control')
  end

  it 'clears version history leaving an empty table' do
    body = described_class.append_row('', version: '0.1.0', date: '2026-01-01', author: 'a', changes: 'created')
    cleared = described_class.clear_history(body)
    expect(described_class.existing_rows(cleared)).to be_empty
    expect(cleared).to include('## Purpose') if body.include?('## Purpose')
  end

  it 'strips version block' do
    body = "# Document Version Control\n\n| Version |\n|---|---|\n| 0.1 |\n\n## Purpose\n\nText\n"
    expect(described_class.strip_block(body)).to include('## Purpose')
  end

  it 'strips orphaned version rows after the version table' do
    body = <<~MD
      # Document Version Control

      | Version | Last Modified | Last Modified By | Document Changes |
      |---------|---------------|------------------|------------------|
      | 0.3.0 | 2026-06-29 | editor | updated |

      | 0.2.0 | 2026-06-29 | seed@isoo.local | Demo seed rows |
      | 0.3.0 | 2026-06-29 | editor | updated |
    MD

    expect(described_class.strip_block(body)).to eq('')
  end

  it 'replaces an existing version row instead of duplicating it' do
    body = described_class.append_row('', version: '0.2.0', date: '2026-01-01', author: 'a', changes: 'first')
    body = described_class.append_row(body, version: '0.2.0', date: '2026-02-01', author: 'b', changes: 'second')

    expect(described_class.sorted_rows(body).map { |r| r['version'] }).to eq(%w[0.2.0])
    expect(body).to include('second')
    expect(body.scan('| 0.2.0 |').size).to eq(1)
  end

  it 'sorts version rows ascending by semver' do
    body = described_class.append_row('', version: '0.2.0', date: '2026-02-01', author: 'a', changes: 'second')
    body = described_class.append_row(body, version: '0.1.0', date: '2026-01-01', author: 'a', changes: 'first')
    rows = described_class.sorted_rows(body)
    expect(rows.map { |r| r['version'] }).to eq(%w[0.1.0 0.2.0])
  end
end
