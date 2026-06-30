# frozen_string_literal: true

class AuthorizedEmailDomains
  def self.allowed?(email)
    domains = configured
    return true if domains.empty?

    domain = extract_domain(email)
    return false if domain.nil?

    domains.include?(domain)
  end

  def self.configured
    ENV.fetch('AUTH_ALLOWED_EMAIL_DOMAINS', '')
       .split(',')
       .map { |part| part.strip.downcase }
       .reject(&:empty?)
       .freeze
  end

  def self.extract_domain(email)
    part = email.to_s.split('@', 2)[1]
    return nil if part.nil? || part.strip.empty?

    part.strip.downcase
  end
  private_class_method :extract_domain
end
