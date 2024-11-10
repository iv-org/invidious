require "yaml"

shardyml = File.open("shard.yml") do |file|
  YAML.parse(file).as_h
end

# Finds all dependencies prefixed with extendious
raw_addons = shardyml["dependencies"].as_h.keys.select(&.as_s.starts_with?("extendious"))
addons = [] of String

raw_addons.map do |addon_name|
  addon_name = addon_name.as_s
  addon_module = addon_name.lchop("extendious-")
  addon_module = addon_module.split("-").map!(&.capitalize).join

  addons << "#{addon_name},#{addon_module}"
end

File.write("src/addons/enabled.txt", addons.join("\n"))
