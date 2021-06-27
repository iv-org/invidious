# Using different browsers would allow us to disguise our traffic even more.
# However, due to the widely different version and operating system values as well as
# their frequency on different OSes we're going to need a separate dataset
# for everything.

AGENT_COMPONENTS = {
  "safari" => {
    "os"       => ["Macintosh; Intel Mac OS X 10_15_7", "Macintosh; Intel Mac OS X 10_15_6"],
    "versions" => ["14.1.1", "14.1", "14.0.3"],
  },

  "firefox" => {
    "os" => ["Macintosh; Intel Mac OS X 10.15'", "Macintosh; Intel Mac OS X 10.14",
             "Windows NT 10.0; Win64; x64", "X11; Ubuntu; Linux x86_64",
             "X11; Linux x86_64"],
    "versions" => ["88.0 ", "89.0"],
  },
}

private def generate_user_agent
  agent_component = AGENT_COMPONENTS.keys.sample(1)[0]
  os = AGENT_COMPONENTS[agent_component]["os"].sample(1)[0]
  version = AGENT_COMPONENTS[agent_component]["versions"].sample(1)[0]
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
