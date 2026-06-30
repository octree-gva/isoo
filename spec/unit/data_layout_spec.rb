# frozen_string_literal: true

require 'fileutils'
require_relative '../spec_helper'
require_relative '../../app/data_layout'

RSpec.describe DataLayout do
  let(:tmp) { Dir.mktmpdir('isoo-data-layout') }
  let(:data_path) { File.join(tmp, 'data') }
  let(:templates_path) { File.join(tmp, 'templates') }

  before do
    stub_const('DataLayout::DATA_PATH', data_path)
    stub_const('DataLayout::TEMPLATES_PATH', templates_path)
    FileUtils.mkdir_p(templates_path)
  end

  after { FileUtils.rm_rf(tmp) }

  it 'creates projects dir and templates symlink' do
    described_class.ensure!

    expect(File.directory?(File.join(data_path, 'projects'))).to be(true)
    link = File.join(data_path, 'templates')
    expect(File.symlink?(link)).to be(true)
    expect(File.expand_path(File.readlink(link))).to eq(templates_path)
  end

  it 'writes nested gitignore excluding templates' do
    described_class.ensure!

    path = File.join(data_path, '.gitignore')
    expect(File.read(path)).to include('/templates')
  end
end
