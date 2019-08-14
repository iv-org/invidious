module DB
  # Empty module used for marking a class as supporting DB:Mapping
  module Mappable; end

  # The `DB.mapping` macro defines how an object is built from a `ResultSet`.
  #
  # It takes hash literal as argument, in which attributes and types are defined.
  # Once defined, `ResultSet#read(t)` populates properties of the class from the
  # `ResultSet`.
  #
  # ```crystal
  # require "db"
  #
  # class Employee
  #   DB.mapping({
  #     title: String,
  #     name:  String,
  #   })
  # end
  #
  # employees = Employee.from_rs(db.query("SELECT title, name FROM employees"))
  # employees[0].title # => "Manager"
  # employees[0].name  # => "John"
  # ```
  #
  # Attributes not mapped with `DB.mapping` are not defined as properties.
  # Also, missing attributes raise a `DB::MappingException`.
  #
  # You can also define attributes for each property.
  #
  # ```crystal
  # class Employee
  #   DB.mapping({
  #     title: String,
  #     name:  {
  #       type:    String,
  #       nilable: true,
  #       key:     "firstname",
  #     },
  #   })
  # end
  # ```
  #
  # Available attributes:
  #
  # * *type* (required) defines its type. In the example above, *title: String* is a shortcut to *title: {type: String}*.
  # * *nilable* defines if a property can be a `Nil`.
  # * **default**: value to use if the property is missing in the result set, or if it's `null` and `nilable` was not set to `true`. If the default value creates a new instance of an object (for example `[1, 2, 3]` or `SomeObject.new`), a different instance will be used each time a row is parsed.
  # * *key* defines which column to read from a `ResultSet`. It defaults to the name of the property.
  # * *converter* takes an alternate type for parsing. It requires a `#from_rs` method in that class, and returns an instance of the given type.
  #
  # The mapping also automatically defines Crystal properties (getters and setters) for each
  # of the keys. It doesn't define a constructor accepting those arguments, but you can provide
  # an overload.
  #
  # The macro basically defines a constructor accepting a `ResultSet` that reads from
  # it and initializes this type's instance variables.
  #
  # This macro also declares instance variables of the types given in the mapping.
  macro mapping(properties, strict = true)
    include ::DB::Mappable

    {% for key, value in properties %}
      {% properties[key] = {type: value} unless value.is_a?(HashLiteral) || value.is_a?(NamedTupleLiteral) %}
    {% end %}

    {% for key, value in properties %}
      {% value[:nilable] = true if value[:type].is_a?(Generic) && value[:type].type_vars.map(&.resolve).includes?(Nil) %}

      {% if value[:type].is_a?(Call) && value[:type].name == "|" &&
              (value[:type].receiver.resolve == Nil || value[:type].args.map(&.resolve).any?(&.==(Nil))) %}
        {% value[:nilable] = true %}
      {% end %}
    {% end %}

    {% for key, value in properties %}
      @{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }}

      def {{key.id}}=(_{{key.id}} : {{value[:type]}} {{ (value[:nilable] ? "?" : "").id }})
        @{{key.id}} = _{{key.id}}
      end

      def {{key.id}}
        @{{key.id}}
      end
    {% end %}

    def self.from_rs(%rs : ::DB::ResultSet)
      %objs = Array(self).new
      %rs.each do
        %objs << self.new(%rs)
      end
      %objs
    ensure
      %rs.close
    end

    def initialize(%rs : ::DB::ResultSet)
      {% for key, value in properties %}
        %var{key.id} = nil
        %found{key.id} = false
      {% end %}

      %rs.each_column do |col_name|
        case col_name
          {% for key, value in properties %}
            when {{value[:key] || key.id.stringify}}
              %found{key.id} = true
              %var{key.id} =
                {% if value[:converter] %}
                  {{value[:converter]}}.from_rs(%rs)
                {% elsif value[:nilable] || value[:default] != nil %}
                  %rs.read(::Union({{value[:type]}} | Nil))
                {% else %}
                  %rs.read({{value[:type]}})
                {% end %}
          {% end %}
          else
            {% if strict %}
              raise ::DB::MappingException.new("unknown result set attribute: #{col_name}")
            {% else %}
              %rs.read
            {% end %}
        end
      end

      {% for key, value in properties %}
        {% unless value[:nilable] || value[:default] != nil %}
          if %var{key.id}.is_a?(Nil) && !%found{key.id}
            raise ::DB::MappingException.new("missing result set attribute: {{(value[:key] || key).id}}")
          end
        {% end %}
      {% end %}

      {% for key, value in properties %}
        {% if value[:nilable] %}
          {% if value[:default] != nil %}
            @{{key.id}} = %found{key.id} ? %var{key.id} : {{value[:default]}}
          {% else %}
            @{{key.id}} = %var{key.id}
          {% end %}
        {% elsif value[:default] != nil %}
          @{{key.id}} = %var{key.id}.is_a?(Nil) ? {{value[:default]}} : %var{key.id}
        {% else %}
          @{{key.id}} = %var{key.id}.as({{value[:type]}})
        {% end %}
      {% end %}
    end
  end

  macro mapping(**properties)
    ::DB.mapping({{properties}})
  end
end
