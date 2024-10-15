
class Invidious::Jobs::MonitorCfgPotokensJob < Invidious::Jobs::BaseJob
  include Invidious
  def begin
    loop do
        
      LOGGER.info("jobs: running MonitorCfgPotokens job")
    
      ReloadPOToken.get_tokens
    
      LOGGER.info("jobs: MonitorCfgPotokens: pot: " + ReloadPOToken.pot.as(String))
      LOGGER.info("jobs: MonitorCfgPotokens: vdata: " + ReloadPOToken.vdata.as(String))
    
      sleep 15.seconds
    end
  end
end
