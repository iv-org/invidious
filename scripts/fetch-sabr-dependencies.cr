require "http"
require "yaml"
require "digest/sha1"
require "option_parser"
require "colorize"

# Script to fetch SABR (Server ABR) dependencies
# These are pre-built bundles for client-side SABR streaming support

SABR_DEPENDENCIES = {
  "shaka-player" => {
    "version" => "4.16.4",
    "files" => [
      {"url" => "https://cdn.jsdelivr.net/npm/shaka-player@4.16.4/dist/shaka-player.ui.js", "dest" => "shaka-player.ui.js"},
      {"url" => "https://cdn.jsdelivr.net/npm/shaka-player@4.16.4/dist/controls.css", "dest" => "controls.css"},
    ]
  },
  "googlevideo" => {
    "version" => "4.0.4",
    "files" => [
      # esm.sh bundled version - fetch full bundle path directly
      {"url" => "https://esm.sh/googlevideo@4.0.4/es2022/sabr-streaming-adapter.bundle.mjs", "dest" => "googlevideo.bundle.min.js"},
    ]
  },
  "youtubei.js" => {
    "version" => "16.0.1",
    "files" => [
      # Use the web bundle from jsdelivr (pre-built by youtubei.js)
      {"url" => "https://cdn.jsdelivr.net/npm/youtubei.js@16.0.1/bundle/browser.min.js", "dest" => "youtubei.bundle.min.js"},
    ]
  },
  "bgutils-js" => {
    "version" => "3.2.0",
    "files" => [
      {"url" => "https://esm.sh/bgutils-js@3.2.0/es2022/bgutils-js.bundle.mjs", "dest" => "bgutils.bundle.min.js"},
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

# Post-process: Patch googlevideo bundle to remove esm.sh import and add process shim
googlevideo_path = "#{sabr_dir}/googlevideo/googlevideo.bundle.min.js"
if File.exists?(googlevideo_path)
  js_content = File.read(googlevideo_path)

  # Add process shim at the beginning and remove the esm.sh import
  process_shim = <<-JS
// Browser-compatible process shim for googlevideo
var __Process$ = { env: {} };

JS

  # Remove the esm.sh import line: import __Process$ from "/node/process.mjs";
  js_content = js_content.gsub(/import\s+__Process\$\s+from\s*["'][^"']+["'];?\s*/, "")

  # Prepend the shim
  js_content = process_shim + js_content

  File.write(googlevideo_path, js_content)
  puts "#{"Patched".colorize(:green)} googlevideo bundle with process shim"
end

# Post-process: Patch bgutils-js bundle to be self-contained
bgutils_path = "#{sabr_dir}/bgutils-js/bgutils.bundle.min.js"
if File.exists?(bgutils_path)
  js_content = File.read(bgutils_path)

  # Check if it's just an export redirect and fetch the actual bundle
  if js_content.includes?("export * from")
    # The esm.sh bundle is just a redirect, we need the actual content
    puts "#{"Info".colorize(:yellow)} bgutils bundle is a redirect, fetching actual content..."

    # Extract the actual path from: export * from "/bgutils-js@3.1.3/es2022/bgutils-js.bundle.mjs";
    if match = js_content.match(/export \* from ["']([^"']+)["']/)
      actual_path = match[1]
      actual_url = "https://esm.sh#{actual_path}"

      HTTP::Client.get(actual_url) do |response|
        if response.status_code == 200
          File.write(bgutils_path, response.body_io.gets_to_end)
          puts "#{"Fetched".colorize(:green)} actual bgutils bundle"
        end
      end
    end
  end
end
