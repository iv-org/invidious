AGENT_COMPONENTS = JSON.parse(File.read("config/user-agents.json")).as_h

private def generate_user_agent
  agent_component = AGENT_COMPONENTS.keys.sample(1)[0]
  os = AGENT_COMPONENTS[agent_component]["os"].as_a.sample(1)[0]
  version = AGENT_COMPONENTS[agent_component]["versions"].as_a.sample(1)[0]
  base = "Mozilla/5.0 "

  case agent_component
  when "safari"
    base += "(#{os}) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/#{version} Safari/605.1.15"
  when "firefox"
    base += "(#{os}; rv:#{version})) Gecko/20100101 Firefox/#{version}"
  end

  return base
end

# Prepare 10 user agents to randomly choose from in
# order to avoid detection
def prepare_random_user_agents
  ua_list = [] of String
  10.times { ua_list << generate_user_agent() }

  # Conserve memory and deallocate AGENT_COMPONENTS
  AGENT_COMPONENTS.clear

  return ua_list
end
