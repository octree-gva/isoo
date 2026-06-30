# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ProjectManifest do
  describe 'annex soft delete' do
    it 'tracks excluded annexes separately from active annexes' do
      Dir.mktmpdir do |tmp|
        manifest_path = File.join(tmp, 'manifest.yaml')
        File.write(manifest_path, {
          'name' => 'Test',
          'annexes' => [
            { 'doc_id' => 'diagram', 'path' => 'annexes/diagram', 'kind' => 'file_annex', 'title' => 'Diagram' }
          ]
        }.to_yaml)

        manifest = described_class.load(tmp)
        manifest.soft_delete_annex!('diagram')

        reloaded = described_class.load(tmp)
        expect(AnnexStatus.excluded?(reloaded.find_annex('diagram'))).to be(true)
        expect(reloaded.active_annexes.map { |annex| annex['doc_id'] }).to eq([])
        expect(reloaded.annexes.size).to eq(1)

        reloaded.restore_annex!('diagram')
        expect(reloaded.active_annexes.map { |annex| annex['doc_id'] }).to eq(%w[diagram])
      end
    end
  end
end
