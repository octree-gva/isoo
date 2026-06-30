# frozen_string_literal: true

require 'fileutils'
require_relative '../spec_helper'

RSpec.describe ProjectCreator do
  describe '#prune_except!' do
    it 'removes every project directory except the kept slug' do
      Dir.mktmpdir do |tmp|
        projects = File.join(tmp, 'projects')
        FileUtils.mkdir_p(File.join(projects, 'demo'))
        FileUtils.mkdir_p(File.join(projects, 'leftover'))
        FileUtils.mkdir_p(File.join(projects, 'spec-run-abc'))

        creator = described_class.new(data_root: tmp)
        removed = creator.prune_except!(keep_slug: 'demo')

        expect(removed).to contain_exactly('leftover', 'spec-run-abc')
        expect(File.directory?(File.join(projects, 'demo'))).to be true
        expect(File.directory?(File.join(projects, 'leftover'))).to be false
        expect(File.directory?(File.join(projects, 'spec-run-abc'))).to be false
      end
    end
  end
end
