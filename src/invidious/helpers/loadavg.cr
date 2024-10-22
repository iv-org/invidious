class Invidious::Loadavg
  
  def self.get_loadavg
    
    str_loadavg = "error"

    if CONFIG.loadavg_enabled
      
      str_loadavg = `/usr/bin/cat /proc/loadavg  | awk -F'[ ]' '{print $1" "$2" "$3}'`
      
    else
      str_loadavg = ""
    end
    
    return str_loadavg

  end
  
end