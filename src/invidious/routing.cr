module Invidious::Routing
  macro get(path, controller, method = :handle)
    get {{ path }} do |env|
      controller_instance = {{ controller }}.new(config, logger)
      controller_instance.{{ method.id }}(env)
    end
  end

  macro post(path, controller, method = :handle)
    post {{ path }} do |env|
      controller_instance = {{ controller }}.new(config, logger)
      controller_instance.{{ method.id }}(env)
    end
  end
end
