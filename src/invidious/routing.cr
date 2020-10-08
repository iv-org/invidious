module Invidious::Routing
  macro get(path, controller)
    get {{ path }} do |env|
      controller_instance = {{ controller }}.new(config)
      controller_instance.handle(env)
    end
  end
end
