class Invidious::Jobs::UpdateDecryptFunctionJob < Invidious::Jobs::BaseJob
  def begin
    loop do
      begin
        DECRYPT_FUNCTION.update_decrypt_function
      rescue ex
        LOGGER.error("UpdateDecryptFunctionJob : #{ex.message}")
      ensure
        sleep 1.minute
        Fiber.yield
      end
    end
  end
end
