# frozen_string_literal: true

module Cache
  module FileFingerprint
    module_function

    def call(path)
      return 'missing' unless File.file?(path)

      stat = File.stat(path)
      "#{stat.mtime.to_i}:#{stat.size}"
    end
  end
end
