# frozen_string_literal: true

module PageAssertions
  LAYOUT_MARKERS = [
    '<!DOCTYPE html>',
    '<html lang="en"',
    'data-theme="isoo"',
    'id="main-content"',
    'class="navbar',
    'window.I18n = ',
    '"name":"ISOO"'
  ].freeze

  ERROR_MARKERS = [
    'NameError',
    'NoMethodError',
    'uninitialized constant',
    'Traceback (innermost first)',
    'Exception at'
  ].freeze

  def expect_rendered_page!(label:, path: nil, include_markers: [], exclude_markers: [])
    body = last_response.body
    context = path ? "#{label} GET #{path}" : label

    expect(last_response.status).to eq(200),
                                    "#{context} => #{last_response.status}\n#{body[0, 800]}"

    ERROR_MARKERS.each do |marker|
      expect(body).not_to include(marker),
                          "#{context} looks like an error page (#{marker.inspect})\n#{body[0, 800]}"
    end

    LAYOUT_MARKERS.each do |marker|
      expect(body).to include(marker),
                      "#{context} missing layout marker #{marker.inspect}\n#{body[0, 800]}"
    end

    include_markers.each do |marker|
      expect(body).to include(marker),
                      "#{context} missing expected content #{marker.inspect}\n#{body[0, 800]}"
    end

    exclude_markers.each do |marker|
      expect(body).not_to include(marker),
                          "#{context} must not include #{marker.inspect}\n#{body[0, 800]}"
    end
  end

  def expect_get_page!(path, label, **)
    get path
    expect_rendered_page!(label: label, path: path, **)
  end

  def follow_redirect_and_expect_page!(label, **)
    follow_redirect!
    expect_rendered_page!(label: label, path: last_request.path, **)
  end
end
