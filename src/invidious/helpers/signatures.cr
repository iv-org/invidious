require "http/params"
require "./sig_helper"

struct Invidious::DecryptFunction
  @last_update : Time = Time.utc - 42.days

  def initialize
    self.check_update
  end

  def check_update
    now = Time.utc

    # If we have updated in the last 5 minutes, do nothing
    return if (now - @last_update) > 5.minutes

    # Get the time when the player was updated, in the event where
    # multiple invidious processes are run in parallel.
    player_ts = Invidious::SigHelper::Client.get_player_timestamp
    player_time = Time.unix(player_ts || 0)

    if (now - player_time) > 5.minutes
      LOGGER.debug("Signature: Player might be outdated, updating")
      Invidious::SigHelper::Client.force_update
      @last_update = Time.utc
    end
  end

  def decrypt_nsig(n : String) : String?
    self.check_update
    return SigHelper::Client.decrypt_n_param(n)
  rescue ex
    LOGGER.debug(ex.message || "Signature: Unknown error")
    LOGGER.trace(ex.inspect_with_backtrace)
    return nil
  end

  def decrypt_signature(str : String) : String?
    self.check_update
    return SigHelper::Client.decrypt_sig(str)
  rescue ex
    LOGGER.debug(ex.message || "Signature: Unknown error")
    LOGGER.trace(ex.inspect_with_backtrace)
    return nil
  end

  def get_sts : UInt64?
    self.check_update
    return SigHelper::Client.get_signature_timestamp
  rescue ex
    LOGGER.debug(ex.message || "Signature: Unknown error")
    LOGGER.trace(ex.inspect_with_backtrace)
    return nil
  end
end
