class Invidious::Uptime
  
  def self.get_uptime
    
    str_uptime = "error"

    if CONFIG.uptime_enabled
          
      # get the uptime
      uptime_cmd = "/usr/bin/uptime"
      uptime_args = "-p"
      process = Process.new(uptime_cmd, [uptime_args], output: Process::Redirect::Pipe)
      str_uptime = process.output.gets_to_end
      
    else
      str_uptime = ""
    end
    
    return str_uptime

  end
  
end