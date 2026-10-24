# frozen_string_literal: true

require 'fileutils'
require 'socket'
require 'ferrum'
require 'puma'
require 'puma/server'

# Boots the Rack app on a local port and drives Ferrum for E2E screenshots under ./tmp.
module E2eBrowser
  SCREENSHOT_ROOT = File.expand_path('../../tmp/e2e-screenshots', __dir__)

  module_function

  def ensure_dir!
    FileUtils.mkdir_p(SCREENSHOT_ROOT)
  end

  def free_port
    server = TCPServer.new('127.0.0.1', 0)
    port = server.addr[1]
    server.close
    port
  end

  def start!(rack_app)
    ensure_dir!
    @port = free_port
    @server = Puma::Server.new(rack_app)
    @server.add_tcp_listener('127.0.0.1', @port)
    @server.run
    wait_until_up!
    @browser = Ferrum::Browser.new(
      headless: true,
      timeout: 45,
      browser_options: {
        'no-sandbox' => nil,
        'disable-dev-shm-usage' => nil
      }
    )
    base_url
  end

  def stop!
    @browser&.quit
    @browser = nil
    @server&.stop(true)
    @server = nil
  end

  def base_url
    "http://127.0.0.1:#{@port}"
  end

  def visit(path)
    @browser.goto("#{base_url}#{path}")
  end

  def screenshot!(name)
    ensure_dir!
    safe = name.to_s.gsub(/[^a-zA-Z0-9_-]+/, '-').gsub(/\A-+|-+\z/, '')
    path = File.join(SCREENSHOT_ROOT, "#{safe}.png")
    @browser.screenshot(path: path, full: true)
    path
  end

  def body
    @browser.body
  end

  def fill(name, value)
    el = @browser.at_css(%([name="#{name}"]))
    raise "missing field #{name}" unless el

    el.focus
    el.evaluate('this.value = arguments[0]', value.to_s)
  end

  def check(name, checked: true)
    el = @browser.at_css(%(input[name="#{name}"][type="checkbox"]))
    raise "missing checkbox #{name}" unless el

    currently = el.property('checked')
    el.click if currently != checked
  end

  def click_css(selector)
    el = @browser.at_css(selector)
    raise "missing element #{selector}" unless el

    el.click
  end

  def wait_for(selector, timeout: 10)
    deadline = Time.now + timeout
    loop do
      el = @browser.at_css(selector)
      return el if el

      raise "timeout waiting for #{selector}" if Time.now > deadline

      sleep 0.1
    end
  end

  def wait_until_up!(attempts: 50)
    attempts.times do
      TCPSocket.new('127.0.0.1', @port).close
      return
    rescue Errno::ECONNREFUSED, Errno::ECONNRESET
      sleep 0.1
    end
    raise "E2E server did not start on port #{@port}"
  end
end
