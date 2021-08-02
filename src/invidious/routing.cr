module Invidious::Routing
  macro get(path, controller, method = :handle)
    get {{ path }} do |env|
      {{ controller }}.{{ method.id }}(env)
    end
  end

  macro post(path, controller, method = :handle)
    post {{ path }} do |env|
      {{ controller }}.{{ method.id }}(env)
    end
  end
end
