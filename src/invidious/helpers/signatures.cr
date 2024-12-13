require "http/params"
require "./sig_helper"

class Invidious::DecryptFunction
  @last_update : Time = Time.utc - 42.days

  def initialize(uri_or_path)
    @client = SigHelper::Client.new(uri_or_path)
    self.check_update
  end

  def check_update
    # If we have updated in the last 5 minutes, do nothing
    return if (Time.utc - @last_update) < 5.minutes

    # Get the amount of time elapsed since when the player was updated, in the
    # event where multiple invidious processes are run in parallel.
    update_time_elapsed = (@client.get_player_timestamp || 301).seconds

    if update_time_elapsed > 5.minutes
      LOGGER.debug("Signature: Player might be outdated, updating")
      @client.force_update
      @last_update = Time.utc
    end
  end

  def decrypt_nsig(n : String) : String?
    self.check_update
    return @client.decrypt_n_param(n)
  rescue ex
    LOGGER.debug(ex.message || "Signature: Unknown error")
    LOGGER.trace(ex.inspect_with_backtrace)
    return nil
  end

  def decrypt_signature(str : String) : String?
    self.check_update
    return @client.decrypt_sig(str)
  rescue ex
    LOGGER.debug(ex.message || "Signature: Unknown error")
    LOGGER.trace(ex.inspect_with_backtrace)
    return nil
  end

  def get_sts : UInt64?
    self.check_update
    return @client.get_signature_timestamp
  rescue ex
    LOGGER.debug(ex.message || "Signature: Unknown error")
    LOGGER.trace(ex.inspect_with_backtrace)
    return nil
  end
end
