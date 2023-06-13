module Invidious::Jobs
  JOBS = [] of BaseJob

  # Automatically generate a structure that wraps the various
  # jobs' configs, so that the following YAML config can be used:
  #
  # jobs:
  #   job_name:
  #     enabled: true
  #     some_property: "value"
  #
  macro finished
    struct JobsConfig
      include YAML::Serializable

      {% for sc in BaseJob.subclasses %}
        # Voodoo macro to transform `Some::Module::CustomJob` to `custom`
        {% class_name = sc.id.split("::").last.id.gsub(/Job$/, "").underscore %}

        getter {{ class_name }} = {{ sc.name }}::Config.new
      {% end %}

      def initialize
      end
    end
  end

  def self.register(job : BaseJob)
    JOBS << job
  end

  def self.start_all
    JOBS.each do |job|
      # Don't run the main rountine if the job is disabled by config
      next if job.disabled?

      spawn { job.begin }
    end
  end
end
