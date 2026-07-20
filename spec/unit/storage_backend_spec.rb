# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe StorageBackend do
  describe '.name' do
    around do |example|
      old = ENV.fetch('STORAGE_BACKEND', nil)
      example.run
    ensure
      if old
        ENV['STORAGE_BACKEND'] = old
      else
        ENV.delete('STORAGE_BACKEND')
      end
    end

    it 'defaults to local' do
      ENV.delete('STORAGE_BACKEND')
      expect(described_class.name).to eq('local')
    end

    it 'rejects unknown backends' do
      ENV['STORAGE_BACKEND'] = 'tape'
      expect { described_class.name }.to raise_error(StorageBackend::PreconditionError, /Unknown/)
    end
  end

  describe '.build' do
    it 'builds local backend' do
      expect(described_class.build(name: 'local')).to be_a(LocalStorageBackend)
    end

    it 'builds git backend' do
      expect(described_class.build(name: 'git')).to be_a(GitStorageBackend)
    end
  end
end

RSpec.describe LocalStorageBackend do
  it 'passes check! on a writable path' do
    Dir.mktmpdir do |tmp|
      backend = described_class.new(data_path: tmp)
      expect(backend.check!).to be true
      expect(backend.flush!('msg')).to be true
      expect(backend.pull!).to eq(status: :ok)
    end
  end

  it 'fails check! when path cannot be created' do
    backend = described_class.new(data_path: '/proc/isoo-no-write-path')
    expect { backend.check! }.to raise_error(StorageBackend::PreconditionError, /not writable/)
  end
end

RSpec.describe GitStorageBackend do
  it 'passes check! without remote' do
    Dir.mktmpdir do |tmp|
      ENV.delete('GIT_REMOTE_URL')
      backend = described_class.new(data_path: tmp)
      expect(backend.check!).to be true
      File.write(File.join(tmp, 'projects', 'note.txt'), 'x')
      expect(backend.flush!('init')).to be true
    end
  end
end

RSpec.describe S3StorageBackend do
  let(:client) { instance_double('Aws::S3::Client') }

  before do
    require 'aws-sdk-s3'
    allow(Aws::S3::Client).to receive(:new).and_return(client)
  end

  def backend(tmp)
    described_class.new(
      data_path: tmp,
      bucket: 'bucket',
      prefix: 'isoo-data',
      access_key_id: 'key',
      secret_access_key: 'secret'
    )
  end

  it 'passes check! when head/put/delete succeed' do
    Dir.mktmpdir do |tmp|
      allow(client).to receive(:head_bucket)
      allow(client).to receive(:put_object)
      allow(client).to receive(:delete_object)
      expect(backend(tmp).check!).to be true
    end
  end

  it 'fails check! without bucket' do
    Dir.mktmpdir do |tmp|
      b = described_class.new(data_path: tmp, bucket: '', access_key_id: 'k', secret_access_key: 's')
      expect { b.check! }.to raise_error(StorageBackend::PreconditionError, /S3_BUCKET/)
    end
  end

  it 'uploads files on flush!' do
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p(File.join(tmp, 'projects', 'demo'))
      File.write(File.join(tmp, 'projects', 'demo', 'a.txt'), 'hi')
      expect(client).to receive(:put_object).with(hash_including(bucket: 'bucket',
                                                                 key: 'isoo-data/projects/demo/a.txt'))
      backend(tmp).flush!('sync')
    end
  end
end

RSpec.describe WebdavStorageBackend do
  it 'fails check! without WEBDAV_URL' do
    Dir.mktmpdir do |tmp|
      b = described_class.new(data_path: tmp, url: '')
      expect { b.check! }.to raise_error(StorageBackend::PreconditionError, /WEBDAV_URL/)
    end
  end
end

RSpec.describe 'storage migrate gate' do
  it 'aborts when target preflight fails before moving data' do
    Dir.mktmpdir do |src|
      FileUtils.mkdir_p(File.join(src, 'projects', 'demo'))
      File.write(File.join(src, 'projects', 'demo', 'x.md'), 'keep')
      source = LocalStorageBackend.new(data_path: src)
      target = S3StorageBackend.new(
        data_path: src,
        bucket: '',
        access_key_id: 'k',
        secret_access_key: 's'
      )
      source.check!
      expect { target.check! }.to raise_error(StorageBackend::PreconditionError)
      expect(File.read(File.join(src, 'projects', 'demo', 'x.md'))).to eq('keep')
    end
  end
end
