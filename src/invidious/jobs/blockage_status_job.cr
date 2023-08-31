class Invidious::Jobs::CheckBlockageStatusJob < Invidious::Jobs::BaseJob
  private getter db : DB::Database

  BLOCKAGE_STATUS = {
    "version" => "1.0",
    "blocked" => false,
  }

  def initialize(@db)
  end

  def begin
    # Logic mostly taken from bypass_captcha_job.cr
    loop do
      begin
        # TODO find performant way of fetching a random video from the videos table.
        video = fetch_video("jNQXAC9IVRw", nil)

        if !video.nil?
          # Assume unblocked
          BLOCKAGE_STATUS["blocked"] = false

          if video.reason.try &.includes?("YouTube is currently trying to block Invidious instances")
            BLOCKAGE_STATUS["blocked"] = true
          else
            # Fetch a random fetch stream. If it returns a 403 then the instance has been blocked.
            random_stream = video.video_streams.sample(1)
            if !random_stream.empty?
              url = URI.parse(random_stream[0]["url"].as_s)
              client = make_client(URI.parse("https://#{url.host.not_nil!}"))

              client.get(url.request_target) do |resp|
                if resp.status_code == 403
                  BLOCKAGE_STATUS["blocked"] = true
                end

                break
              end
            end
          end
        end
      rescue ex
        LOGGER.error("CheckBlockageStatusJob: #{ex.message}")
      ensure
        LOGGER.debug("CheckBlockageStatusJob: Done, sleeping for #{CONFIG.blockage_check_interval}")
        sleep CONFIG.blockage_check_interval
        Fiber.yield
      end
    end
  end
end
