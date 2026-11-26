require "http"
require "yaml"
require "json"
require "digest/sha256"
require "option_parser"
require "colorize"
require "file_utils"

# Script to fetch SABR (Server ABR) dependencies
#
# Shaka Player, youtubei.js and bgutils-js are downloaded at build time from the
# npm registry, like the video.js dependencies (scripts/fetch-player-dependencies.cr),
# and aren't committed. Their packages already contain files a browser can load
# as they are. Each package tarball is checked against a pinned SHA-256 digest
# before anything is extracted from it. When bumping a version, update the
# digest: `curl -s https://registry.npmjs.org/NAME/-/NAME-X.Y.Z.tgz | sha256sum`.
#
# googlevideo is bundled locally from npm via scripts/bundle-sabr-libs.js
# (`npm run bundle-sabr`) and committed: its package is made of modules that
# import @bufbuild/protobuf, which a browser can't resolve without a bundler.

SABR_DEPENDENCIES = {
  "shaka-player" => {
    "version" => "5.3.6",
    "sha256"  => "0405c850ad2e2da688c6aeb980dadac96b88f2b381724a775bc192375837c410",
    # Files or directories extracted from the package tarball: path in the
    # tarball => destination
    "files" => {
      "package/dist/shaka-player.ui.js" => "shaka-player.ui.js",
      "package/dist/controls.css"       => "controls.css",
    },
  },
  "youtubei.js" => {
    "version" => "18.3.0",
    "sha256"  => "ffcdab3af8b05c66ee5b38475928c5cacbc603018eca64d846a1693729994dd8",
    # The package's self-contained browser bundle
    "files" => {
      "package/bundle/browser.js" => "browser.js",
    },
  },
  "bgutils-js" => {
    "version" => "4.0.3",
    "sha256"  => "4ae4a52040c5b3a77452ccf5fa7c2edeee36bbfc84e37943ad9b61d85293bb9b",
    # ES modules without dependencies. They import each other with relative
    # paths, so they go to a directory named after the version: a version bump
    # changes their URLs (static assets are cached for a long time). The entry
    # module bgutils.js is written below.
    "files" => {
      "package/dist" => "{version}",
    },
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

# googlevideo isn't fetched at build time: its bundle is built with
# `npm run bundle-sabr` and committed. Make sure it matches the version pinned
# in package.json, so a version bump can't silently keep serving an old bundle.
NPM_BUNDLES = {
  "googlevideo" => "googlevideo/googlevideo.bundle.min.js",
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

      files = dep_info["files"].as(Hash(String, String)).transform_values(&.gsub("{version}", version))
      if config["version"].as_s != version
        # Old files are only removed once the new ones are downloaded and verified
        dependencies_to_install << dep_name
      elsif files.values.any? { |dest| !File.exists?("#{path}/#{dest}") }
        # Same version, but a file is missing: download it again
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
    files = dep_info["files"].as(Hash(String, String)).transform_values(&.gsub("{version}", version))
    dest_path = "#{sabr_dir}/#{dep_name}"
    url = "https://registry.npmjs.org/#{dep_name}/-/#{dep_name}-#{version}.tgz"

    tarball = HTTP::Client.get(url) do |response|
      if response.status_code != 200
        raise Exception.new("Failed to fetch #{url}: HTTP #{response.status_code}")
      end
      response.body_io.getb_to_end
    end

    digest = Digest::SHA256.hexdigest(tarball)
    if digest != dep_info["sha256"]
      raise Exception.new("SHA-256 mismatch for #{url}: expected #{dep_info["sha256"]}, got #{digest}")
    end

    # Extract the needed files to a temporary directory, then replace the
    # installed ones only once everything is extracted.
    tmp_dir = File.tempname("sabr-#{dep_name}")
    Dir.mkdir_p(tmp_dir)
    begin
      tarball_path = "#{tmp_dir}/package.tgz"
      File.write(tarball_path, tarball)
      status = Process.run("tar", ["-xzf", tarball_path, "-C", tmp_dir] + files.keys, error: Process::Redirect::Inherit)
      raise Exception.new("Failed to extract #{url}") unless status.success?

      # Clean old files (the .gitignore stays)
      Dir.children(dest_path).each do |child|
        FileUtils.rm_rf("#{dest_path}/#{child}") unless child == ".gitignore"
      end

      files.each do |source, dest|
        if Dir.exists?("#{tmp_dir}/#{source}")
          FileUtils.cp_r("#{tmp_dir}/#{source}", "#{dest_path}/#{dest}")
        else
          File.copy("#{tmp_dir}/#{source}", "#{dest_path}/#{dest}")
        end
      end

      # Only the JavaScript and CSS are served: drop source maps and type
      # declarations, and the references to the maps (DevTools would report a
      # failed load). Done after the SHA-256 check, which covers the download.
      Dir.glob("#{dest_path}/**/*.{map,ts}").each { |f| File.delete(f) }
      Dir.glob("#{dest_path}/**/*.js").each do |js_path|
        content = File.read(js_path)
        stripped = content.gsub(/\n\/\/# sourceMappingURL=[^\n]*\s*\z/, "\n")
        File.write(js_path, stripped) if stripped != content
      end
    ensure
      FileUtils.rm_rf(tmp_dir)
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

# bgutils-js entry module: the pieces the player uses, as one `BG` object
# (sabr_loader.js imports it). Its imports point to the versioned directory.
bgutils_version = SABR_DEPENDENCIES["bgutils-js"]["version"].as(String)
bgutils_entry = <<-JS
  // Generated by scripts/fetch-sabr-dependencies.cr
  import { BotGuardClient, parseChallengeData } from './#{bgutils_version}/exports/botguard.js';
  import { WebPoMinter, createColdStartToken } from './#{bgutils_version}/exports/webpo.js';
  import { buildURL, GOOG_API_KEY } from './#{bgutils_version}/exports/utils.js';

  export const BG = { BotGuardClient, parseChallengeData, WebPoMinter, createColdStartToken, buildURL, GOOG_API_KEY };

  JS
bgutils_entry_path = "#{sabr_dir}/bgutils-js/bgutils.js"
if !File.exists?(bgutils_entry_path) || File.read(bgutils_entry_path) != bgutils_entry
  File.write(bgutils_entry_path, bgutils_entry)
end

# Note: googlevideo is bundled locally from npm via scripts/bundle-sabr-libs.js
# (esbuild, platform: 'browser'). No esm.sh fetch or post-patching is required.
