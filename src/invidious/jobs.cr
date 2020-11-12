module Invidious::Jobs
  JOBS = [] of BaseJob

  def self.register(job : BaseJob)
    JOBS << job
  end

  def self.start_all
    JOBS.each do |job|
      spawn { job.begin }
    end
  end
end
