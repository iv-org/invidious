class Invidious::Uptime
  
  def self.get_uptime
    
    str_uptime = "error"

    if CONFIG.uptime_enabled
          
      # get the uptime
      str_uptime = `/usr/bin/uptime -p`
      
    else
      str_uptime = ""
    end
    
    return str_uptime

  end
  
end
