
class Invidious::Jobs::MonitorCfgTokensJob < Invidious::Jobs::BaseJob
  include Invidious
  def begin
    loop do
        
      LOGGER.info("jobs: running MonitorCfgTokensJob job")
    
      ReloadTokens.get_tokens
    
      LOGGER.info("jobs: MonitorCfgTokensJob: pot: " + ReloadTokens.pot.as(String))
      LOGGER.info("jobs: MonitorCfgTokensJob: vdata: " + ReloadTokens.vdata.as(String))
    
      sleep 1.minutes
    end
  end
end
