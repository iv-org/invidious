class Invidious::Jobs::UpdateDecryptFunctionJob < Invidious::Jobs::BaseJob
  DECRYPT_FUNCTION = [] of {SigProc, Int32}

  def begin
    loop do
      begin
        decrypt_function = fetch_decrypt_function
        DECRYPT_FUNCTION.clear
        decrypt_function.each { |df| DECRYPT_FUNCTION << df }
      rescue ex
        # TODO: Log error
        next
      ensure
        sleep 1.minute
        Fiber.yield
      end
    end
  end
end
