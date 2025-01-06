class Invidious::Jobs::InstanceListRefreshJob < Invidious::Jobs::BaseJob
  # We update the internals of a constant as so it can be accessed from anywhere
  # within the codebase
  #
  # "INSTANCES" => Array(Tuple(String, String))  # region, instance

  INSTANCES = {"INSTANCES" => [] of Tuple(String, String)}

  def initialize
  end

  def begin
    loop do
      refresh_instances
      LOGGER.info("InstanceListRefreshJob: Done, sleeping for 30 minutes")
      sleep 30.minute
      Fiber.yield
    end
  end

  # Refreshes the list of instances used for redirects.
  #
  # Does the following three checks for each instance
  # -  Is it a clear-net instance?
  # -  Is it an instance with a good uptime?
  # -  Is it an updated instance?
  private def refresh_instances
    raw_instance_list = self.fetch_instances
    filtered_instance_list = [] of Tuple(String, String)

    raw_instance_list.each do |instance_data|
      # TODO allow Tor hidden service instances when the current instance
      # is also a hidden service. Same for i2p and any other non-clearnet instances.
      begin
        domain = instance_data[0]
        info = instance_data[1]
        stats = info["stats"]

        next unless info["type"] == "https"
        next if bad_uptime?(info["monitor"])
        next if outdated?(stats["software"]["version"])

        filtered_instance_list << {info["region"].as_s, domain.as_s}
      rescue ex
        if domain
          LOGGER.info("InstanceListRefreshJob: failed to parse information from '#{domain}' because \"#{ex}\"\n\"#{ex.backtrace.join('\n')}\"  ")
        else
          LOGGER.info("InstanceListRefreshJob: failed to parse information from an instance because \"#{ex}\"\n\"#{ex.backtrace.join('\n')}\"  ")
        end
      end
    end

    if !filtered_instance_list.empty?
      INSTANCES["INSTANCES"] = filtered_instance_list
    end
  end

  # Fetches information regarding instances from api.invidious.io or an otherwise configured URL
  private def fetch_instances : Array(JSON::Any)
    begin
      # We directly call the stdlib HTTP::Client here as it allows us to negate the effects
      # of the force_resolve config option. This is needed as api.invidious.io does not support ipv6
      # and as such the following request raises if we were to use force_resolve with the ipv6 value.
      instance_api_client = HTTP::Client.new(URI.parse("https://api.invidious.io"))

      # Timeouts
      instance_api_client.connect_timeout = 10.seconds
      instance_api_client.dns_timeout = 10.seconds

      raw_instance_list = JSON.parse(instance_api_client.get("/instances.json").body).as_a
      instance_api_client.close
    rescue ex : Socket::ConnectError | IO::TimeoutError | JSON::ParseException
      raw_instance_list = [] of JSON::Any
    end

    return raw_instance_list
  end

  # Checks if the given target instance is outdated
  private def outdated?(target_instance_version) : Bool
    remote_commit_date = target_instance_version.as_s.match(/\d{4}\.\d{2}\.\d{2}/)
    return false if !remote_commit_date

    remote_commit_date = Time.parse(remote_commit_date[0], "%Y.%m.%d", Time::Location::UTC)
    local_commit_date = Time.parse(CURRENT_VERSION, "%Y.%m.%d", Time::Location::UTC)

    return (remote_commit_date - local_commit_date).abs.days > 30
  end

  # Checks if the uptime of the target instance is greater than 90% over a 30 day period
  private def bad_uptime?(target_instance_health_monitor) : Bool
    return true if !target_instance_health_monitor["down"].as_bool == false
    return true if target_instance_health_monitor["uptime"].as_f < 90

    return false
  end
end
