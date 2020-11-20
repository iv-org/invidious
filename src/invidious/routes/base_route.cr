abstract class Invidious::Routes::BaseRoute
  private getter config : Config
  private getter logger : Invidious::LogHandler

  def initialize(@config, @logger)
  end
end
