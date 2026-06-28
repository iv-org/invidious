require "http"
require "yaml"
require "digest/sha1"
require "option_parser"
require "colorize"

# Script to fetch SABR (Server ABR) dependencies
# These are pre-built bundles for client-side SABR streaming support

SABR_DEPENDENCIES = {
  "shaka-player" => {
    "version" => "5.1.10",
    "files" => [
      {"url" => "https://cdn.jsdelivr.net/npm/shaka-player@5.1.10/dist/shaka-player.ui.js", "dest" => "shaka-player.ui.js"},
      {"url" => "https://cdn.jsdelivr.net/npm/shaka-player@5.1.10/dist/controls.css", "dest" => "controls.css"},
    ]
  },
  # googlevideo + bgutils-js are bundled locally from npm via scripts/bundle-sabr-libs.js
  # (no esm.sh fetch). youtubei.js is also bundled locally from npm, but we keep a
  # pre-built jsDelivr copy as the esbuild entry for reproducibility.
  "youtubei.js" => {
    "version" => "17.0.1",
    "files" => [
      {"url" => "https://cdn.jsdelivr.net/npm/youtubei.js@17.0.1/bundle/browser.js", "dest" => "youtubei.bundle.min.js"},
    ]
  },
}

def update_versions_yaml(dep_name : String, version : String)
  File.open("assets/js/sabr/#{dep_name}/versions.yml", "w") do |io|
    YAML.build(io) do |builder|
      builder.mapping do
        builder.scalar "version"
        builder.scalar version
      end
    end
  end
end

# Create the main sabr directory if it doesn't exist
sabr_dir = "assets/js/sabr"
Dir.mkdir_p(sabr_dir) unless Dir.exists?(sabr_dir)

dependencies_to_install = [] of String

SABR_DEPENDENCIES.each do |dep_name, dep_info|
  path = "#{sabr_dir}/#{dep_name}"
  version = dep_info["version"].as(String)

  if !Dir.exists?(path)
    Dir.mkdir_p(path)
    dependencies_to_install << dep_name
  else
    if File.exists?("#{path}/versions.yml")
      config = File.open("#{path}/versions.yml") do |file|
        YAML.parse(file).as_h
      end

      if config["version"].as_s != version
        # Clean old files
        Dir.glob("#{path}/*.js").each { |f| File.delete(f) }
        Dir.glob("#{path}/*.css").each { |f| File.delete(f) }
        dependencies_to_install << dep_name
      end
    else
      dependencies_to_install << dep_name
    end
  end
end

channel = Channel(String | Exception).new

dependencies_to_install.each do |dep_name|
  spawn do
    dep_info = SABR_DEPENDENCIES[dep_name]
    version = dep_info["version"].as(String)
    files = dep_info["files"].as(Array(Hash(String, String)))
    dest_path = "#{sabr_dir}/#{dep_name}"

    files.each do |file_info|
      url = file_info["url"]
      dest_file = file_info["dest"]

      HTTP::Client.get(url) do |response|
        if response.status_code == 200
          File.write("#{dest_path}/#{dest_file}", response.body_io.gets_to_end)
        else
          raise Exception.new("Failed to fetch #{url}: HTTP #{response.status_code}")
        end
      end
    end

    update_versions_yaml(dep_name, version)
    channel.send(dep_name)
  rescue ex
    channel.send(ex)
  end
end

if dependencies_to_install.empty?
  puts "#{"SABR".colorize(:blue)} #{"dependencies".colorize(:green)} are satisfied"
else
  puts "#{"Resolving".colorize(:green)} #{"SABR".colorize(:blue)} dependencies"
  dependencies_to_install.size.times do
    result = channel.receive

    if result.is_a? Exception
      raise result
    end

    puts "#{"Fetched".colorize(:green)} #{result.colorize(:blue)}"
  end
end

# Post-process: Remove Google Fonts from Shaka controls.css
shaka_css_path = "#{sabr_dir}/shaka-player/controls.css"
if File.exists?(shaka_css_path)
  css_content = File.read(shaka_css_path)
  # Remove @font-face rule that loads from fonts.gstatic.com
  css_content = css_content.gsub(/@font-face\{[^}]*fonts\.gstatic\.com[^}]*\}/, "")
  # Replace Roboto font-family with system fonts
  css_content = css_content.gsub(/font-family:\s*Roboto[^;]*;/, "font-family:-apple-system,BlinkMacSystemFont,\"Segoe UI\",Roboto,\"Helvetica Neue\",Arial,sans-serif;")
  File.write(shaka_css_path, css_content)
  puts "#{"Patched".colorize(:green)} Shaka CSS to use system fonts"
end

# Note: googlevideo and bgutils-js are now bundled locally from npm via
# scripts/bundle-sabr-libs.js (esbuild, platform: 'browser', with
# process.env.NODE_ENV defined to 'production'). No esm.sh fetch or
# post-patching is required.
