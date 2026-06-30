# frozen_string_literal: true

module SessionIdle
  DEFAULT_TIMEOUT_SECONDS = 7200

  module_function

  def timeout_seconds
    ENV.fetch('SESSION_IDLE_TIMEOUT_SECONDS', DEFAULT_TIMEOUT_SECONDS).to_i
  end

  def touch!(session)
    session['last_activity_at'] = Time.now.to_i
  end

  def expired?(session)
    return false unless session['user']

    last = session['last_activity_at'].to_i
    return false if last.zero?

    Time.now.to_i - last > timeout_seconds
  end
end
