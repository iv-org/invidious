class ReloadPOToken

  @@instance = new
  
  def self.pot
    @@pot
  end
  
  def self.vdata
    @@vdata
  end  
  
  def initialize
    
    @@pot = "error"
    @@vdata = "error"
    
  end
  
  def self.get_tokens

    # Load config from file or YAML string env var
    env_config_file = "INVIDIOUS_CONFIG_FILE"
    env_config_yaml = "INVIDIOUS_CONFIG"

    config_file = ENV.has_key?(env_config_file) ? ENV.fetch(env_config_file) : "config/config.yml"
    config_yaml = ENV.has_key?(env_config_yaml) ? ENV.fetch(env_config_yaml) : File.read(config_file)

    config = Config.from_yaml(config_yaml)
    
    
    
    
    # Update config from env vars (upcased and prefixed with "INVIDIOUS_")
    {% for ivar in Config.instance_vars %}
        {% env_id = "INVIDIOUS_#{ivar.id.upcase}" %}

        if ENV.has_key?({{env_id}})
            env_value = ENV.fetch({{env_id}})
            success = false

            # Use YAML converter if specified
            {% ann = ivar.annotation(::YAML::Field) %}
            {% if ann && ann[:converter] %}
                config.{{ivar.id}} = {{ann[:converter]}}.from_yaml(YAML::ParseContext.new, YAML::Nodes.parse(ENV.fetch({{env_id}})).nodes[0])
                success = true

            # Use regular YAML parser otherwise
            {% else %}
                {% ivar_types = ivar.type.union? ? ivar.type.union_types : [ivar.type] %}
                # Sort types to avoid parsing nulls and numbers as strings
                {% ivar_types = ivar_types.sort_by { |ivar_type| ivar_type == Nil ? 0 : ivar_type == Int32 ? 1 : 2 } %}
                {{ivar_types}}.each do |ivar_type|
                    if !success
                        begin
                            config.{{ivar.id}} = ivar_type.from_yaml(env_value)
                            success = true
                        rescue
                            # nop
                        end
                    end
                end
            {% end %}

            # Exit on fail
            if !success
                puts %(Config.{{ivar.id}} failed to parse #{env_value} as {{ivar.type}})
                exit(1)
            end
        end
    {% end %}


    @@pot = config.po_token
    @@vdata = config.visitor_data

  end
  
  def self.get_instance
    return @@instance
  end
  
end