# frozen_string_literal: true

module Cache
  class NullStore
    def enabled?
      false
    end

    def fetch(_key, scope: 'global', expires_in: nil, &block) # rubocop:disable Lint/UnusedMethodArgument
      block.call
    end

    def bump(_scope)
      nil
    end

    def delete(*)
      nil
    end
  end
end
