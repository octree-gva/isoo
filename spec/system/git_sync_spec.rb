# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'git sync', type: :request do
  around do |example|
    old_remote = ENV.fetch('GIT_REMOTE_URL', nil)
    old_backend = ENV.fetch('STORAGE_BACKEND', nil)
    ENV['STORAGE_BACKEND'] = 'git'
    Container.reset!
    example.run
  ensure
    if old_remote
      ENV['GIT_REMOTE_URL'] = old_remote
    else
      ENV.delete('GIT_REMOTE_URL')
    end
    if old_backend
      ENV['STORAGE_BACKEND'] = old_backend
    else
      ENV.delete('STORAGE_BACKEND')
    end
    Container.reset!
  end

  it 'returns 404 when remote sync is not configured' do
    ENV.delete('GIT_REMOTE_URL')
    post '/git/sync'
    expect(last_response.status).to eq(404)
  end

  it 'returns 404 when STORAGE_BACKEND is not git' do
    ENV['STORAGE_BACKEND'] = 'local'
    ENV['GIT_REMOTE_URL'] = 'git@example.com:acme/isoo-data.git'
    Container.reset!
    post '/git/sync'
    expect(last_response.status).to eq(404)
  end

  it 'shows sync button when STORAGE_BACKEND=git and GIT_REMOTE_URL is set' do
    ENV['GIT_REMOTE_URL'] = 'git@example.com:acme/isoo-data.git'
    get '/projects'
    expect(last_response.status).to eq(200)
    expect(last_response.body).to include('Sync')
  end

  it 'pulls from remote and shows confirmation' do
    Dir.mktmpdir do |tmp|
      bare = File.join(tmp, 'remote.git')
      system('git', 'init', '--bare', '-b', 'main', bare, out: File::NULL)
      ENV['GIT_REMOTE_URL'] = bare
      Container.reset!

      post '/git/sync', {}, 'HTTP_REFERER' => '/projects'
      expect(last_response.status).to eq(302)

      follow_redirect!
      expect(last_response.body).to include('Synced from remote')
    end
  end
end
