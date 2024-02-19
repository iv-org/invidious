require "http"
require "yaml"
require "digest/sha1"
require "option_parser"
require "colorize"

class Dependency
  @dependency_config : Hash(YAML::Any, YAML::Any)

  def initialize(
    required_dependencies : Hash(YAML::Any, YAML::Any),
    @dependency : String,
    @tmp_dir_path : String,
    @minified : Bool,
    @skip_checksum : Bool
  )
    @dependency_config = required_dependencies[@dependency].as_h

    @download_path = "#{@tmp_dir_path}/#{@dependency}"
    @destination_path = "assets/videojs/#{@dependency}"
  end

  private def request
    HTTP::Client.get("https://registry.npmjs.org/#{@dependency}/-/#{@dependency}-#{@dependency_config["version"]}.tgz") do |response|
      Dir.mkdir(@download_path)
      data = response.body_io.gets_to_end
      File.write("#{@download_path}/package.tgz", data)

      # https://github.com/iv-org/invidious/pull/2397#issuecomment-922375908
      if !@skip_checksum && Digest::SHA1.hexdigest(data) != @dependency_config["shasum"]
        raise Exception.new("Checksum for '#{@dependency}' failed")
      end
    end
  end

  private def move_file(full_target_path, extension)
    minified_target_path = sprintf(full_target_path, {"file_extension": ".min.#{extension}"})

    if @minified && File.exists?(minified_target_path)
      target_path = minified_target_path
    else
      target_path = sprintf(full_target_path, {"file_extension": ".#{extension}"})
    end

    target_path = Path[target_path]

    if download_as = @dependency_config.dig?(YAML::Any.new("install_instructions"), YAML::Any.new("download_as"))
      destination_path = "#{@destination_path}/#{sprintf(download_as.as_s, {"file_extension": ".#{extension}"})}"
    else
      destination_path = Path[@destination_path].join(target_path.basename)
    end

    File.copy(target_path, destination_path)
  end

  private def fetch_path(is_css)
    if is_css
      instruction_path = "css_path"
    else
      instruction_path = "js_path"
    end

    # https://github.com/crystal-lang/crystal/issues/14305
    if raw_target_path = @dependency_config.dig?(YAML::Any.new("install_instructions"), YAML::Any.new(instruction_path))
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
          builder.scalar "#{@dependency_config["version"]}"

          builder.scalar "minified"
          builder.scalar @minified
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

# Hacky solution to get separated arguments when called from invidious.cr
if ARGV.size == 1
  parser_args = [] of String
  ARGV[0].split(",") { |str| parser_args << str.strip }
else
  parser_args = ARGV
end

# Taken from https://crystal-lang.org/api/1.1.1/OptionParser.html
minified = false
skip_checksum = false

OptionParser.parse(parser_args) do |parser|
  parser.banner = "Usage: Fetch VideoJS dependencies [arguments]"
  parser.on("-m", "--minified", "Use minified versions of VideoJS dependencies (performance and bandwidth benefit)") { minified = true }
  parser.on("--skip-checksum", "Skips the checksum validation of downloaded files") { skip_checksum = true }

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

required_dependencies = File.open("videojs-dependencies.yml") do |file|
  YAML.parse(file).as_h
end

# The first step is to check which dependencies we'll need to install.
# If the version we have requested in `videojs-dependencies.yml` is the
# same as what we've installed, we shouldn't do anything. Likewise, if it's
# different or the requested dependency just isn't present, then it needs to be
# installed.

dependencies_to_install = [] of String

required_dependencies.keys.each do |dep|
  dep = dep.as_s
  path = "assets/videojs/#{dep}"

  # Check for missing dependencies
  #
  # Does the directory exist?
  # Does the Javascript file exist?
  # Does the CSS file exist?
  #
  # videojs-contrib-quality-levels.js is the only dependency that does not come with a CSS file so
  # we skip the check there
  if !Dir.exists?(path)
    Dir.mkdir(path)
    next dependencies_to_install << dep
  elsif !(File.exists?("#{path}/#{dep}.js") || File.exists?("#{path}/versions.yml"))
    next dependencies_to_install << dep
  elsif dep != "videojs-contrib-quality-levels" && !File.exists?("#{path}/#{dep}.css")
    next dependencies_to_install << dep
  end

  # Check if we need to update the dependency

  config = File.open("#{path}/versions.yml") do |file|
    YAML.parse(file).as_h
  end

  if config["version"].as_s != required_dependencies[dep]["version"].as_s || config["minified"].as_bool != minified
    # Clear directory
    {"*.js", "*.css"}.each do |file_types|
      Dir.glob("#{path}/#{file_types}").each do |file_path|
        File.delete(file_path)
      end
    end

    dependencies_to_install << dep
  end
end

# Now we begin the fun part of installing the dependencies.
# But first we'll setup a temp directory to store the plugins
tmp_dir_path = "#{Dir.tempdir}/invidious-videojs-dep-install"
Dir.mkdir(tmp_dir_path) if !Dir.exists? tmp_dir_path
channel = Channel(String | Exception).new

dependencies_to_install.each do |dep|
  spawn do
    dependency = Dependency.new(required_dependencies, dep, tmp_dir_path, minified, skip_checksum)
    dependency.fetch
    channel.send(dep)
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
`rm -rf #{tmp_dir_path}`
