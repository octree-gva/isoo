# frozen_string_literal: true

require 'json'
require 'base64'
require 'openssl'
require 'digest'

class DocumentCipher
  CONFIDENTIAL_LEVELS = %w[Confidential Secret].freeze

  class << self
    def confidential?(classification)
      CONFIDENTIAL_LEVELS.include?(classification.to_s)
    end

    def encrypt(plaintext)
      cipher = setup_cipher(:encrypt)
      iv = cipher.random_iv
      ciphertext = cipher.update(plaintext) + cipher.final
      JSON.generate(
        'iv' => Base64.strict_encode64(iv),
        'tag' => Base64.strict_encode64(cipher.auth_tag),
        'data' => Base64.strict_encode64(ciphertext)
      )
    end

    def decrypt(blob)
      payload = JSON.parse(blob)
      cipher = setup_cipher(:decrypt)
      cipher.iv = Base64.decode64(payload['iv'])
      cipher.auth_tag = Base64.decode64(payload['tag'])
      (
        cipher.update(Base64.decode64(payload['data'])) + cipher.final
      ).force_encoding(Encoding::UTF_8)
    end

    def key
      secret = ENV.fetch('ENCRYPTION_SECRET') do
        raise 'ENCRYPTION_SECRET required for confidential documents'
      end
      Digest::SHA256.digest(secret)
    end

    private

    def setup_cipher(mode)
      cipher = OpenSSL::Cipher.new('aes-256-gcm')
      cipher.send(mode)
      cipher.key = key
      cipher.auth_data = ''
      cipher
    end
  end
end
