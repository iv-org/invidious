class Invidious::Jobs::UpdateDecryptFunctionJob < Invidious::Jobs::BaseJob
  private getter logger : Invidious::LogHandler

  def initialize(@logger)
  end

  def begin
    loop do
      begin
        DECRYPT_FUNCTION.update_decrypt_function
      rescue ex
        logger.error("UpdateDecryptFunctionJob : #{ex.message}")
      ensure
        sleep 1.minute
        Fiber.yield
      end
    end
  end
end
