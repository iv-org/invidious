class Invidious::Routes::Privacy < Invidious::Routes::BaseRoute
  def handle(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    templated "privacy"
  end
end
