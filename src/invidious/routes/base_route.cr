abstract class Invidious::Routes::BaseRoute
  private getter config : Config

  def initialize(@config)
  end

  abstract def handle(env)
end
