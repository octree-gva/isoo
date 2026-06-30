# frozen_string_literal: true

require_relative '../spec_helper'

RSpec.describe ErrorResponse do
  it 'renders an HTML error page with i18n copy' do
    body = described_class.render(status: 502, detail: 'Upstream unavailable')

    expect(body).to include('<!DOCTYPE html>', '502', 'Bad gateway', 'Upstream unavailable')
    expect(body).to include('Back to projects')
  end

  it 'returns a rack triplet' do
    status, headers, body = described_class.rack(status: 400, detail: 'Missing field')

    expect(status).to eq(400)
    expect(headers['content-type']).to include('text/html')
    expect(body.first).to include('Bad request', 'Missing field')
  end
end
