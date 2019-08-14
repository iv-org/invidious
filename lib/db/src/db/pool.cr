require "weak_ref"

module DB
  class Pool(T)
    @initial_pool_size : Int32
    # maximum amount of objects in the pool. Either available or in use.
    @max_pool_size : Int32
    @available = Set(T).new
    @total = [] of T
    @checkout_timeout : Float64
    # maximum amount of retry attempts to reconnect to the db. See `Pool#retry`.
    @retry_attempts : Int32
    @retry_delay : Float64

    def initialize(@initial_pool_size = 1, @max_pool_size = 0, @max_idle_pool_size = 1, @checkout_timeout = 5.0,
                   @retry_attempts = 1, @retry_delay = 0.2, &@factory : -> T)
      @initial_pool_size.times { build_resource }

      @availability_channel = Channel(Nil).new
      @waiting_resource = 0
      @mutex = Mutex.new
    end

    # close all resources in the pool
    def close : Nil
      @total.each &.close
      @total.clear
      @available.clear
    end

    def checkout : T
      resource = if @available.empty?
                   if can_increase_pool
                     build_resource
                   else
                     wait_for_available
                     pick_available
                   end
                 else
                   pick_available
                 end

      @available.delete resource
      resource.before_checkout
      resource
    end

    # ```
    # selected, is_candidate = pool.checkout_some(candidates)
    # ```
    # `selected` be a resource from the `candidates` list and `is_candidate` == `true`
    # or `selected` will be a new resource and `is_candidate` == `false`
    def checkout_some(candidates : Enumerable(WeakRef(T))) : {T, Bool}
      # TODO honor candidates while waiting for availables
      # this will allow us to remove `candidates.includes?(resource)`
      candidates.each do |ref|
        resource = ref.value
        if resource && is_available?(resource)
          @available.delete resource
          resource.before_checkout
          return {resource, true}
        end
      end

      resource = checkout
      {resource, candidates.any? { |ref| ref.value == resource }}
    end

    def release(resource : T) : Nil
      if can_increase_idle_pool
        @available << resource
        resource.after_release
        @availability_channel.send nil if are_waiting_for_resource?
      else
        resource.close
        @total.delete(resource)
      end
    end

    # :nodoc:
    # Will retry the block if a `ConnectionLost` exception is thrown.
    # It will try to reuse all of the available connection right away,
    # but if a new connection is needed there is a `retry_delay` seconds delay.
    def retry
      current_available = @available.size
      # if the pool hasn't reach the max size, allow 1 attempt
      # to make a new connection if needed without sleeping
      current_available += 1 if can_increase_pool

      (current_available + @retry_attempts).times do |i|
        begin
          sleep @retry_delay if i >= current_available
          return yield
        rescue e : ConnectionLost
          # if the connection is lost close it to release resources
          # and remove it from the known pool.
          delete(e.connection)
          e.connection.close
        rescue e : ConnectionRefused
          # a ConnectionRefused means a new connection
          # was intended to be created
          # nothing to due but to retry soon
        end
      end
      raise PoolRetryAttemptsExceeded.new
    end

    # :nodoc:
    def each_resource
      @available.each do |resource|
        yield resource
      end
    end

    # :nodoc:
    def is_available?(resource : T)
      @available.includes?(resource)
    end

    # :nodoc:
    def delete(resource : T)
      @total.delete(resource)
      @available.delete(resource)
    end

    private def build_resource : T
      resource = @factory.call
      @total << resource
      @available << resource
      resource
    end

    private def can_increase_pool
      @max_pool_size == 0 || @total.size < @max_pool_size
    end

    private def can_increase_idle_pool
      @available.size < @max_idle_pool_size
    end

    private def pick_available
      @available.first
    end

    private def wait_for_available
      timeout = TimeoutHelper.new(@checkout_timeout.to_f64)
      inc_waiting_resource

      timeout.start

      # TODO update to select keyword for crystal 0.19
      index, _ = Channel.select(@availability_channel.receive_select_action, timeout.receive_select_action)
      case index
      when 0
        timeout.cancel
        dec_waiting_resource
      when 1
        dec_waiting_resource
        raise DB::PoolTimeout.new
      else
        raise DB::Error.new
      end
    end

    private def inc_waiting_resource
      @mutex.synchronize do
        @waiting_resource += 1
      end
    end

    private def dec_waiting_resource
      @mutex.synchronize do
        @waiting_resource -= 1
      end
    end

    private def are_waiting_for_resource?
      @mutex.synchronize do
        @waiting_resource > 0
      end
    end

    class TimeoutHelper
      def initialize(@timeout : Float64)
        @abort_timeout = false
        @timeout_channel = Channel(Nil).new
      end

      def receive_select_action
        @timeout_channel.receive_select_action
      end

      def start
        spawn do
          sleep @timeout
          unless @abort_timeout
            @timeout_channel.send nil
          end
        end
      end

      def cancel
        @abort_timeout = true
      end
    end
  end
end
