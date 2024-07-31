require "http/params"
require "./sig_helper"

struct Invidious::DecryptFunction
  @last_update = Time.monotonic - 42.days

  def initialize
    self.check_update
  end

  def check_update
    now = Time.monotonic
    if (now - @last_update) > 60.seconds
      LOGGER.debug("Signature: Player might be outdated, updating")
      Invidious::SigHelper::Client.force_update
      @last_update = Time.monotonic
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
