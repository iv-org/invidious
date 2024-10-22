class Invidious::Loadavg
  
  def self.get_loadavg
    
    str_loadavg = "error"

    if CONFIG.loadavg_enabled
          
      # get the uptime
      #loadavg_cmd = "/usr/bin/cat /proc/loadavg  | awk -F'[ ]' '{print $1\" \"$2\" \"$3}'"
      #loadavg_args = ""
      #process = Process.new(loadavg_cmd, [loadavg_args], output: Process::Redirect::Pipe)
      #str_loadavg = process.output.gets_to_end
      
      str_loadavg = "test"
      
    else
      str_loadavg = ""
    end
    
    return str_loadavg

  end
  
end