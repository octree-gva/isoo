# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe 'error pages', type: :request do
  it 'shows a copyable stack trace for unexpected 500 errors outside production' do
    allow(TableDocumentStore).to receive(:new).and_wrap_original do |method, *args|
      store = method.call(*args)
      allow(store).to receive(:read).and_raise(RuntimeError, 'boom for backtrace')
      store
    end

    slug = create_test_project!(name: 'Error Trace')
    get "/projects/#{slug}/docs/data-asset-register-ropa"

    expect(last_response.status).to eq(500)
    expect(last_response.body).to include('Server error')
    expect(last_response.body).to include('RuntimeError: boom for backtrace')
    expect(last_response.body).to include('data-copy-backtrace')
    expect(last_response.body).to include('error-backtrace-text')
    expect(last_response.body).to include('Copy stack trace')
  end
end
