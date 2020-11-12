class Invidious::Routes::Licenses < Invidious::Routes::BaseRoute
  def handle(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    rendered "licenses"
  end
end
