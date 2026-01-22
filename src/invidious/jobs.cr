module Invidious::Jobs
  # This line defines an empty array named JOBS to hold objects of type BaseJob.
  JOBS = [] of BaseJob

  # SEMAPHORE is a Channel that allows up to 5 items (jobs) to be processed concurrently.
  # This is a way to limit the maximum number of jobs running at the same time to 5.
  SEMAPHORE = ::Channel(Nil).new(5)

  # The `macro finished` block is executed once the module definition is complete.
  macro finished
    # Define a struct named JobsConfig inside the module. 
    # This struct is for storing configuration for different jobs.
    struct JobsConfig
      include YAML::Serializable  # Allows serialization and deserialization from YAML.

      # This loop iterates over all subclasses of BaseJob.
      {% for sc in BaseJob.subclasses %}
        # Generate a getter method for each job. The job's class name is transformed
        # from something like `Some::Module::CustomJob` to a simpler form `custom`.
        {% class_name = sc.id.split("::").last.id.gsub(/Job$/, "").underscore %}

        getter {{ class_name }} = {{ sc.name }}::Config.new
      {% end %}

      # Define an empty initializer.
      def initialize
      end
    end
  end

  # This class method allows registration of a job to the JOBS array.
  def self.register(job : BaseJob)
    JOBS << job
  end

  # This class method starts all registered jobs.
  def self.start_all
    # Iterate over each job in the JOBS array.
    JOBS.each do |job|
      # Send a nil value to the SEMAPHORE channel. This is like acquiring a "slot".
      # If the SEMAPHORE is full (5 jobs running), this line will block until a slot is free.
      SEMAPHORE.send(nil)

      # Start a new concurrent fiber (lightweight thread) for the job.
      spawn do
        begin
          # If the job is disabled in its configuration, skip the execution.
          next if job.disabled?

          # Start the job by calling its 'begin' method.
          job.begin
        rescue ex
          # If an exception occurs, log the error.
          Log.error { "Job failed: #{ex.message}" }
        ensure
          # After the job is finished or if an error occurred, release the "slot" in the semaphore.
          SEMAPHORE.receive
        end
      end
    end
  end
end
