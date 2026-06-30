# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'

RSpec.describe TextDocumentStore do
  it 'reads and saves text document' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      store.write('docs/doc/doc.md', FrontMatter.dump(
                                       { 'iso27001' => { 'version' => '0.1.0' } },
                                       "# Document Version Control\n\n| Version |\n"
                                     ))
      store.write('docs/doc/doc.schema.yaml', {
        'sections' => [
          { 'key' => 'purpose', 'label' => 'Purpose', 'level' => 'h2',
            'role' => 'body', 'editable' => true }
        ]
      }.to_yaml)

      tds = TextDocumentStore.new(store)
      data = tds.read('docs/doc')
      expect(data[:schema]['sections'].length).to eq(1)

      tds.save('docs/doc', fields: { 'purpose' => 'Our purpose' }, version: '0.2.0',
                           date: '2026-01-01', author: 'a@b.c', changes: 'updated purpose')
      saved = tds.read('docs/doc')
      expect(saved[:meta].dig('iso27001', 'version')).to eq('0.2.0')
      expect(saved[:body]).to include('Our purpose')
    end
  end

  it 'extracts h2 sections without bleeding into the next section' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      body = <<~MD
        # Document Version Control

        | Version |

        # Malware and Antivirus Policy

        ## Principle

        Company devices have adequate protection.

        ## Approved Software

        Only company approved software is installed.

        ## Policy Compliance

        Compliance intro.

        ## Compliance Measurement

        Verified by audit.
      MD
      store.write('policies/malware/malware.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, body))
      store.write('policies/malware/malware.schema.yaml', {
        'sections' => [
          { 'key' => 'principle', 'label' => 'Principle', 'level' => 'h2', 'role' => 'body', 'editable' => true },
          { 'key' => 'approved_software', 'label' => 'Approved Software', 'level' => 'h2', 'role' => 'body',
            'editable' => true },
          { 'key' => 'policy_compliance', 'label' => 'Policy Compliance', 'level' => 'h2', 'role' => 'body',
            'editable' => true },
          { 'key' => 'compliance_measurement', 'label' => 'Compliance Measurement', 'level' => 'h2',
            'role' => 'body', 'editable' => true }
        ]
      }.to_yaml)

      fields = described_class.new(store).read('policies/malware')[:fields]
      expect(fields['principle']).to eq('Company devices have adequate protection.')
      expect(fields['approved_software']).to eq('Only company approved software is installed.')
      expect(fields['policy_compliance']).to eq('Compliance intro.')
      expect(fields['compliance_measurement']).to eq('Verified by audit.')
    end
  end

  it 'extracts is-04 risk policy sections independently' do
    template_md = File.join(__dir__, '../../data/templates/voca/policies/is-04-risk-management-policy',
                            'is-04-risk-management-policy.md')
    template_schema = File.join(__dir__, '../../data/templates/voca/policies/is-04-risk-management-policy',
                                'is-04-risk-management-policy.schema.yaml')
    skip 'template missing' unless File.file?(template_md)

    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      _meta, body = FrontMatter.parse(File.read(template_md, encoding: 'UTF-8'))
      store.write('policies/is-04/is-04.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, body))
      store.write('policies/is-04/is-04.schema.yaml', File.read(template_schema))

      fields = described_class.new(store).read('policies/is-04')[:fields]
      expect(fields['purpose']).to include('purpose of this policy')
      expect(fields['scope']).to include('All employees and third-party users')
      expect(fields['scope']).not_to include('## Principle')
      expect(fields['principle']).to include('appropriate and adequate risk')
      expect(fields['risk_evaluation']).to include('Financial Performance')
      expect(fields['risk_evaluation']).not_to include('Policy Compliance')
    end
  end

  it 'preserves non-editable title headings when saving' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      body = <<~MD
        # Document Version Control

        | Version |

        # Risk Management Policy

        ## Purpose

        Original purpose.
      MD
      store.write('policies/risk/risk.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, body))
      store.write('policies/risk/risk.schema.yaml', {
        'sections' => [
          { 'key' => 'title', 'label' => 'Risk Management Policy', 'level' => 'h1', 'role' => 'title',
            'editable' => false },
          { 'key' => 'purpose', 'label' => 'Purpose', 'level' => 'h2', 'role' => 'body', 'editable' => true }
        ]
      }.to_yaml)

      described_class.new(store).save(
        'policies/risk',
        fields: { 'purpose' => 'Updated purpose.' },
        version: '0.2.0',
        date: '2026-01-01',
        author: 'tester',
        changes: 'Updated purpose'
      )

      saved = described_class.new(store).read('policies/risk')
      expect(saved[:body]).to include("# Risk Management Policy\n\n## Purpose\n\nUpdated purpose.")
      expect(saved[:fields]['purpose']).to eq('Updated purpose.')
    end
  end

  it 'accumulates version control rows on save' do
    Dir.mktmpdir do |tmp|
      store = FileStore.new(tmp)
      body = VersionControlWriter.append_row('', version: '0.1.0', date: '2026-01-01', author: 'a', changes: 'created')
      body += "## Purpose\n\nOriginal.\n"
      store.write('docs/doc/doc.md', FrontMatter.dump({ 'iso27001' => { 'version' => '0.1.0' } }, body))
      store.write('docs/doc/doc.schema.yaml', {
        'sections' => [
          { 'key' => 'purpose', 'label' => 'Purpose', 'level' => 'h2', 'role' => 'body', 'editable' => true }
        ]
      }.to_yaml)

      tds = described_class.new(store)
      tds.save('docs/doc', fields: { 'purpose' => 'Updated' }, version: '0.2.0',
                           date: '2026-02-01', author: 'b', changes: 'updated')
      rows = tds.read('docs/doc')[:version_control_rows]
      expect(rows.map { |r| r['version'] }).to eq(%w[0.1.0 0.2.0])
    end
  end
end
