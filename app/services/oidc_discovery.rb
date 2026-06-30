# frozen_string_literal: true

require 'json'
require 'net/http'
require 'uri'

module OidcDiscovery
  module_function

  def endpoints
    @endpoints ||= load_endpoints
  end

  def reset!
    @endpoints = nil
  end

  def load_endpoints
    internal = ENV.fetch('OIDC_ISSUER_INTERNAL', ENV.fetch('OIDC_ISSUER'))
    public = ENV.fetch('OIDC_ISSUER')
    doc = fetch_discovery(internal)
    {
      authorize: rewrite_host(doc.fetch('authorization_endpoint'), public),
      token: rewrite_host(doc.fetch('token_endpoint'), internal),
      userinfo: rewrite_host(doc.fetch('userinfo_endpoint'), internal)
    }
  end

  def fetch_discovery(issuer)
    cache = Container.cache
    return fetch_discovery_uncached(issuer) unless cache.enabled?

    cache.fetch("oidc:discovery:#{issuer}", scope: 'oidc', expires_in: 300) do
      fetch_discovery_uncached(issuer)
    end
  end

  def fetch_discovery_uncached(issuer)
    uri = URI("#{issuer.chomp('/')}/.well-known/openid-configuration")
    res = request(uri, Net::HTTP::Get.new(uri))
    raise "OIDC discovery failed (#{res.code})" unless res.is_a?(Net::HTTPSuccess)

    JSON.parse(res.body)
  end

  def post_form(url, fields)
    uri = URI(url)
    req = Net::HTTP::Post.new(uri)
    req.set_form_data(fields)
    parse_json(request(uri, req))
  end

  def get_json(url, headers = {})
    uri = URI(url)
    req = Net::HTTP::Get.new(uri)
    headers.each { |key, value| req[key] = value }
    parse_json(request(uri, req))
  end

  def request(uri, req)
    apply_instance_host!(req, uri)
    Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') { |http| http.request(req) }
  end

  def apply_instance_host!(req, uri)
    public = URI(ENV.fetch('OIDC_ISSUER'))
    return if uri.host == public.host

    req['Host'] = public.port == uri.default_port ? public.host : "#{public.host}:#{public.port}"
  end

  def rewrite_host(url, base)
    endpoint = URI(url)
    target = URI(base.chomp('/'))
    endpoint.host = target.host
    endpoint.port = target.port if target.port
    endpoint.scheme = target.scheme
    endpoint.to_s
  end

  def parse_json(res)
    JSON.parse(res.body)
  rescue JSON::ParserError
    {}
  end
end
