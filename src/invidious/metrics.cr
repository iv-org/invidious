# Module containing an optional Kemal handler, which can be used
# to collect metrics about the usage of various Invidious routes.
module Metrics
  record MetricLabels, request_method : String, request_route : String, response_code : Int32

  # Counts how many a given route was used
  REQUEST_COUNTERS = Hash(MetricLabels, Int64).new

  # Counts how much time was used to handle requests to each route
  REQUEST_DURATION_SECONDS_SUMS = Hash(MetricLabels, Float32).new

  # The handler which will record metrics when registered in a Kemal application
  METRICS_COLLECTOR = RouteMetricsCollector.new(REQUEST_COUNTERS, REQUEST_DURATION_SECONDS_SUMS)

  class RouteMetricsCollector < Kemal::Handler
    def initialize(
      @num_of_request_counters : Hash(MetricLabels, Int64),
      @request_duration_seconds_sums : Hash(MetricLabels, Float32)
    )
    end

    def call(context : HTTP::Server::Context)
      request_handling_started = Time.utc
      begin
        call_next(context)
      ensure
        request_handling_finished = Time.utc
        request_path = context.route.path
        request_method = context.request.method
        seconds_spent_handling = (request_handling_finished - request_handling_started).to_f
        response_status = context.response.status_code.to_i

        LOGGER.trace("Collecting metrics: handling #{request_method} #{request_path} took #{seconds_spent_handling}s and finished with status #{response_status}")
        metric_key = MetricLabels.new request_path, request_method, response_status

        unless @num_of_request_counters.has_key?(metric_key)
          @num_of_request_counters[metric_key] = 0
        end
        @num_of_request_counters[metric_key] += 1

        unless @request_duration_seconds_sums.has_key?(metric_key)
          @request_duration_seconds_sums[metric_key] = 0.0
        end
        @request_duration_seconds_sums[metric_key] += seconds_spent_handling
      end
    end
  end
end
