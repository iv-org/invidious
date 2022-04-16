module DB::Serializable
  macro included
    {% verbatim do %}
      macro finished
        def self.type_array
          \{{ @type.instance_vars
            .reject { |var| var.annotation(::DB::Field) && var.annotation(::DB::Field)[:ignore] }
            .map { |name| name.stringify }
          }}
        end

        def initialize(tuple)
          \{% for var in @type.instance_vars %}
            \{% ann = var.annotation(::DB::Field) %}
            \{% if ann && ann[:ignore] %}
            \{% else %}
              @\{{var.name}} = tuple[:\{{var.name.id}}]
            \{% end %}
          \{% end %}
        end

        def to_a
          \{{ @type.instance_vars
            .reject { |var| var.annotation(::DB::Field) && var.annotation(::DB::Field)[:ignore] }
            .map { |name| name }
          }}
        end
      end
    {% end %}
  end
end

module JSON::Serializable
  macro included
    {% verbatim do %}
      macro finished
        def initialize(tuple)
          \{% for var in @type.instance_vars %}
            \{% ann = var.annotation(::JSON::Field) %}
            \{% if ann && ann[:ignore] %}
            \{% else %}
              @\{{var.name}} = tuple[:\{{var.name.id}}]
            \{% end %}
          \{% end %}
        end
      end
    {% end %}
  end
end

macro templated(_filename, template = "template", navbar_search = true)
  navbar_search = {{navbar_search}}

  {{ filename = "src/invidious/views/" + _filename + ".ecr" }}
  {{ layout = "src/invidious/views/" + template + ".ecr" }}

  __content_filename__ = {{filename}}
  content = Kilt.render({{filename}})
  Kilt.render({{layout}})
end

macro rendered(filename)
  Kilt.render("src/invidious/views/#{{{filename}}}.ecr")
end

# Similar to Kemals halt method but works in a
# method.
macro haltf(env, status_code = 200, response = "")
  {{env}}.response.status_code = {{status_code}}
  {{env}}.response.print {{response}}
  {{env}}.response.close
  return
end
