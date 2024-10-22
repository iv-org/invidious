
class Invidious::Jobs::MonitorCfgTokensJob < Invidious::Jobs::BaseJob
  include Invidious
  def begin
    loop do
        
      LOGGER.info("jobs: running MonitorCfgTokensJob job")
    
      Invidious::TokenMon.get_tokens
    
      LOGGER.info("jobs: MonitorCfgTokensJob: pot: " + Invidious::TokenMon.pot.as(String))
      LOGGER.info("jobs: MonitorCfgTokensJob: vdata: " + Invidious::TokenMon.vdata.as(String))
    
      sleep 1.minutes
    end
  end
end
