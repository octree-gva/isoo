# frozen_string_literal: true

require_relative '../spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe GitService do
  around do |example|
    old_remote = ENV.fetch('GIT_REMOTE_URL', nil)
    old_push = ENV.fetch('GIT_FORCE_PUSH', nil)
    example.run
  ensure
    if old_remote
      ENV['GIT_REMOTE_URL'] = old_remote
    else
      ENV.delete('GIT_REMOTE_URL')
    end
    if old_push
      ENV['GIT_FORCE_PUSH'] = old_push
    else
      ENV.delete('GIT_FORCE_PUSH')
    end
  end

  it 'commits changes' do
    Dir.mktmpdir do |tmp|
      git = described_class.new(tmp)
      File.write(File.join(tmp, 'a.txt'), 'x')
      expect(git.commit('init')).to be true
      expect(git.commit('noop')).to be false
    end
  end

  it 'reports remote sync disabled without GIT_REMOTE_URL' do
    ENV.delete('GIT_REMOTE_URL')
    expect(described_class.remote_sync_enabled?).to be false
    expect(described_class.new(Dir.mktmpdir).pull).to eq({ status: :disabled })
  end

  it 'pulls updates from origin/main' do
    Dir.mktmpdir do |tmp|
      bare = File.join(tmp, 'remote.git')
      system('git', 'init', '--bare', '-b', 'main', bare, out: File::NULL)

      upstream = File.join(tmp, 'upstream')
      system('git', 'clone', bare, upstream, out: File::NULL)
      Dir.chdir(upstream) do
        system('git', 'config', 'user.email', 'test@example.com')
        system('git', 'config', 'user.name', 'Test')
        File.write('remote.txt', 'from remote')
        system('git', 'add', 'remote.txt')
        system('git', 'commit', '-m', 'remote change')
        system('git', 'push', 'origin', 'main')
      end

      data = File.join(tmp, 'data')
      FileUtils.mkdir_p(data)
      ENV['GIT_REMOTE_URL'] = bare
      git = described_class.new(data)
      File.write(File.join(data, 'local.txt'), 'local')
      expect(git.commit('local')).to be true

      result = git.pull
      expect(result[:status]).to eq(:ok)
      expect(File.read(File.join(data, 'remote.txt'))).to eq('from remote')
      expect(File.exist?(File.join(data, 'local.txt'))).to be false
    end
  end

  it 'refuses pull with uncommitted changes' do
    Dir.mktmpdir do |tmp|
      bare = File.join(tmp, 'remote.git')
      system('git', 'init', '--bare', '-b', 'main', bare, out: File::NULL)
      data = File.join(tmp, 'data')
      FileUtils.mkdir_p(data)
      ENV['GIT_REMOTE_URL'] = bare
      git = described_class.new(data)
      git.commit('init') # creates repo
      File.write(File.join(data, 'dirty.txt'), 'x')
      git.commit('add file')
      File.write(File.join(data, 'dirty.txt'), 'changed')

      expect(git.pull).to eq({ status: :dirty })
    end
  end
end
