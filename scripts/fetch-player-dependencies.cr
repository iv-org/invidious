require "http"
require "yaml"
require "file_utils"
require "digest/sha1"
require "option_parser"
require "colorize"

# Represents an "install_instruction" section specified per dependency in `videojs-dependencies.yml`
#
# This is used to modify the download logic for dependencies that are packaged differently.
struct InstallInstruction
  include YAML::Serializable

  property js_path : String? = nil
  property css_path : String? = nil
  property download_as : String? = nil
end

# Object representing a dependency specified within `videojs-dependencies.yml`
class ConfigDependency
  include YAML::Serializable

  property version : String
  property shasum : String

  property install_instructions : InstallInstruction? = nil

  # Checks if the current dependency needs to be installed/updated
  def fetch?(name : String)
    path = "assets/videojs/#{name}"

    # Check for missing dependency files
    #
    # Does the directory exist?
    # Does the Javascript file exist?
    # Does the CSS file exist?
    #
    # videojs-contrib-quality-levels.js is the only dependency that does not come with a CSS file so
    # we skip the check there
    if !Dir.exists?(path)
      Dir.mkdir(path)
      return true
    elsif !(File.exists?("#{path}/#{name}.js") || File.exists?("#{path}/versions.yml"))
      return true
    elsif name != "videojs-contrib-quality-levels" && !File.exists?("#{path}/#{name}.css")
      return true
    end

    # Check if we need to update the dependency

    versions = File.open("#{path}/versions.yml") do |file|
      YAML.parse(file).as_h
    end

    if versions["version"].as_s != self.version || versions["minified"].as_bool != CONFIG.minified
      # Clear directory
      {"*.js", "*.css"}.each do |file_types|
        Dir.glob("#{path}/#{file_types}").each do |file_path|
          File.delete(file_path)
        end
      end

      return true
    end

    return false
  end
end

# Object representing the `videojs-dependencies.yml` file
class PlayerDependenciesConfig
  include YAML::Serializable

  property version : String
  property dependencies : Hash(YAML::Any, ConfigDependency)

  def get_dependencies_to_fetch
    return self.dependencies.select { |name, config| config.fetch?(name.as_s) }
  end
end

# Runtime Dependency config for easy access to all the variables
class Config
  property minified : Bool
  property skip_checksum : Bool
  property clear_cache : Bool

  property dependency_config : PlayerDependenciesConfig

  def initialize(path : String)
    @minified = false
    @skip_checksum = false
    @clear_cache = false

    @dependency_config = PlayerDependenciesConfig.from_yaml(File.read(path))
  end
end

# Object representing a player dependency
class Dependency
  @config : ConfigDependency

  def initialize(@config : ConfigDependency, @dependency : String, @tmp_dir_path : String)
    @download_path = "#{@tmp_dir_path}/#{@dependency}"
    @destination_path = "assets/videojs/#{@dependency}"
  end

  private def validate_checksum(io)
    if !CONFIG.skip_checksum && Digest::SHA1.hexdigest(io) != @config.shasum
      raise IO::Error.new("Checksum for '#{@dependency}' failed")
    end
  end

  # Requests and downloads a specific dependency from NPM
  #
  # Validates a cached tarball if it already exists.
  private def request
    downloaded_package_path = "#{@download_path}/package.tgz"

    # Create a download directory for the dependency if it does not already exist
    if Dir.exists?(@download_path)
      # Validate checksum of existing cached tarball
      # Fetches a new one when the checksum fails.
      if File.exists?(downloaded_package_path)
        begin
          return self.validate_checksum(File.open(downloaded_package_path))
        rescue IO::Error
        end
      end
    else
      Dir.mkdir(@download_path)
    end

    HTTP::Client.get("https://registry.npmjs.org/#{@dependency}/-/#{@dependency}-#{@config.version}.tgz") do |response|
      data = response.body_io.gets_to_end
      File.write(downloaded_package_path, data)
      self.validate_checksum(data)
    end
  end

  private def move_file(full_target_path, extension)
    minified_target_path = sprintf(full_target_path, {"file_extension": ".min.#{extension}"})

    if CONFIG.minified && File.exists?(minified_target_path)
      target_path = minified_target_path
    else
      target_path = sprintf(full_target_path, {"file_extension": ".#{extension}"})
    end

    if download_as = @config.install_instructions.try &.download_as
      destination_path = "#{@destination_path}/#{sprintf(download_as, {"file_extension": ".#{extension}"})}"
    else
      destination_path = @destination_path
    end

    FileUtils.cp(target_path, destination_path)
  end

  private def fetch_path(is_css)
    if is_css
      raw_target_path = @config.install_instructions.try &.css_path
    else
      raw_target_path = @config.install_instructions.try &.js_path
    end

    if raw_target_path
      return "#{@download_path}/package/#{raw_target_path}"
    else
      return "#{@download_path}/package/dist/#{@dependency}%{file_extension}"
    end
  end

  private def move_js_file
    return self.move_file(self.fetch_path(is_css: false), "js")
  end

  private def move_css_file
    path = self.fetch_path(is_css: true)

    if File.exists?(sprintf(path, {"file_extension": ".css"}))
      return move_file(path, "css")
    end
  end

  private def update_versions_yaml
    File.open("#{@destination_path}/versions.yml", "w") do |io|
      YAML.build(io) do |builder|
        builder.mapping do
          # Versions
          builder.scalar "version"
          builder.scalar "#{@config.version}"

          builder.scalar "minified"
          builder.scalar CONFIG.minified
        end
      end
    end
  end

  def fetch
    self.request

    # Crystal's stdlib provides no way of extracting a tarball
    `tar -vzxf '#{@download_path}/package.tgz' -C '#{@download_path}'`
    raise "Extraction for #{@dependency} failed" if !$?.success?

    self.move_js_file
    self.move_css_file

    self.update_versions_yaml
  end
end

CONFIG = Config.new("videojs-dependencies.yml")

# Hacky solution to get separated arguments when called from invidious.cr
if ARGV.size == 1
  parser_args = [] of String
  ARGV[0].split(",") { |str| parser_args << str.strip }
else
  parser_args = ARGV
end

# Taken from https://crystal-lang.org/api/1.1.1/OptionParser.html
OptionParser.parse(parser_args) do |parser|
  parser.banner = "Usage: Fetch VideoJS dependencies [arguments]"
  parser.on("-m", "--minified", "Use minified versions of VideoJS dependencies (performance and bandwidth benefit)") { CONFIG.minified = true }
  parser.on("--skip-checksum", "Skips the checksum validation of downloaded files") { CONFIG.skip_checksum = true }
  parser.on("--clear-cache", "Clears the cache and re-downloads all dependency files") { CONFIG.clear_cache = true }

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end

  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

dependencies_to_install = CONFIG.dependency_config.get_dependencies_to_fetch

tmp_dir_path = "#{Dir.tempdir}/invidious-videojs-dep-install"
Dir.mkdir(tmp_dir_path) if !Dir.exists? tmp_dir_path
channel = Channel(String | Exception).new

dependencies_to_install.each do |dep_name, dependency_config|
  spawn do
    dependency = Dependency.new(dependency_config, dep_name.as_s, tmp_dir_path)
    dependency.fetch
    channel.send(dep_name.as_s)
  rescue ex
    channel.send(ex)
  end
end

if dependencies_to_install.empty?
  puts "#{"Player".colorize(:blue)} #{"dependencies".colorize(:green)} are satisfied"
else
  puts "#{"Resolving".colorize(:green)} #{"player".colorize(:blue)} dependencies"
  dependencies_to_install.size.times do
    result = channel.receive

    if result.is_a? Exception
      raise result
    end

    puts "#{"Fetched".colorize(:green)} #{result.colorize(:blue)}"
  end
end

# Cleanup
if CONFIG.clear_cache
  FileUtils.rm_r("#{tmp_dir_path}")
end
