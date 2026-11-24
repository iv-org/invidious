require "http"
require "yaml"
require "json"
require "digest/sha256"
require "option_parser"
require "colorize"

# Script to fetch SABR (Server ABR) dependencies
# These are pre-built bundles for client-side SABR streaming support
#
# Each file is checked against a pinned SHA-256 digest of the raw download
# (before any post-processing), so a modified CDN response is rejected. When
# bumping a version, update the digests (they match the files of the npm
# package tarball).

SABR_DEPENDENCIES = {
  "shaka-player" => {
    "version" => "5.3.6",
    "files"   => [
      {
        "url"    => "https://cdn.jsdelivr.net/npm/shaka-player@5.3.6/dist/shaka-player.ui.js",
        "dest"   => "shaka-player.ui.js",
        "sha256" => "54e0fa5abe72fc97f540a70ac3978e42f22d67a2b23963fdda57183a4a77ab11",
      },
      {
        "url"    => "https://cdn.jsdelivr.net/npm/shaka-player@5.3.6/dist/controls.css",
        "dest"   => "controls.css",
        "sha256" => "72bd7fac17c47814bef30053c2e21ec65061fd224c70055cadd83e7fb2c1eefa",
      },
    ],
  },
  # googlevideo, bgutils-js and youtubei.js are bundled locally from npm via
  # scripts/bundle-sabr-libs.js (`npm run bundle-sabr`).
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

# The npm libraries are not fetched at build time: their bundles are built with
# `npm run bundle-sabr` and committed. Make sure they match the versions pinned
# in package.json, so a version bump can't silently keep serving old bundles.
NPM_BUNDLES = {
  "googlevideo" => "googlevideo/googlevideo.bundle.min.js",
  "youtubei.js" => "youtubei.js/youtubei.bundle.min.js",
  "bgutils-js"  => "bgutils-js/bgutils.bundle.min.js",
}

if !File.exists?("package.json")
  STDERR.puts "#{"SABR".colorize(:blue)}: package.json is missing, it is needed to check the SABR bundles (copy it next to scripts/ and assets/)."
  exit(1)
end
pinned_versions = JSON.parse(File.read("package.json"))["dependencies"].as_h
outdated_bundles = [] of String

NPM_BUNDLES.each do |dep_name, bundle_file|
  pinned = pinned_versions[dep_name]?.try &.as_s
  versions_path = "#{sabr_dir}/#{dep_name}/versions.yml"
  bundled = File.exists?(versions_path) ? YAML.parse(File.read(versions_path))["version"]?.try &.as_s : nil

  if pinned.nil?
    outdated_bundles << "#{dep_name}: not pinned in package.json"
  elsif !File.exists?("#{sabr_dir}/#{bundle_file}")
    outdated_bundles << "#{dep_name}: #{sabr_dir}/#{bundle_file} is missing (package.json pins #{pinned})"
  elsif bundled != pinned
    outdated_bundles << "#{dep_name}: bundled #{bundled || "unknown version"}, but package.json pins #{pinned}"
  end
end

if !outdated_bundles.empty?
  STDERR.puts "#{"SABR".colorize(:blue)} bundles don't match package.json:"
  outdated_bundles.each { |line| STDERR.puts "  - #{line}" }
  STDERR.puts "Run `npm install && npm run bundle-sabr` to rebuild them, then commit the result."
  exit(1)
end

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
        # Old files are only removed once the new ones are downloaded and verified
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

    # Download and verify every file before touching the installed ones
    downloads = files.map do |file_info|
      url = file_info["url"]

      content = HTTP::Client.get(url) do |response|
        if response.status_code != 200
          raise Exception.new("Failed to fetch #{url}: HTTP #{response.status_code}")
        end
        response.body_io.getb_to_end
      end

      digest = Digest::SHA256.hexdigest(content)
      if digest != file_info["sha256"]
        raise Exception.new("SHA-256 mismatch for #{url}: expected #{file_info["sha256"]}, got #{digest}")
      end

      {file_info["dest"], content}
    end

    # Clean old files
    Dir.glob("#{dest_path}/*.js").each { |f| File.delete(f) }
    Dir.glob("#{dest_path}/*.css").each { |f| File.delete(f) }

    downloads.each do |dest_file, content|
      File.write("#{dest_path}/#{dest_file}", content)
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

# Note: googlevideo, bgutils-js and youtubei.js are bundled locally from npm via
# scripts/bundle-sabr-libs.js (esbuild, platform: 'browser', with
# process.env.NODE_ENV defined to 'production'). No esm.sh fetch or
# post-patching is required.
