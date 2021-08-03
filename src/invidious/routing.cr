module Invidious::Routing
  {% for http_method in {"get", "post", "delete", "options", "patch", "put", "head"} %}

    macro {{http_method.id}}(path, controller, method = :handle)
      {{http_method.id}} \{{ path }} do |env|
        \{{ controller }}.\{{ method.id }}(env)
      end
    end

  {% end %}
end
