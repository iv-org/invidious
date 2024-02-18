require "http"
require "yaml"
require "digest/sha1"
require "option_parser"
require "colorize"

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

def update_versions_yaml(required_dependencies, minified, dep_name)
  File.open("assets/videojs/#{dep_name}/versions.yml", "w") do |io|
    YAML.build(io) do |builder|
      builder.mapping do
        # Versions
        builder.scalar "version"
        builder.scalar "#{required_dependencies[dep_name]["version"]}"

        builder.scalar "minified"
        builder.scalar minified
      end
    end
  end
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
    dep_name = dep
    download_path = "#{tmp_dir_path}/#{dep}"
    dest_path = "assets/videojs/#{dep}"

    HTTP::Client.get("https://registry.npmjs.org/#{dep}/-/#{dep}-#{required_dependencies[dep]["version"]}.tgz") do |response|
      Dir.mkdir(download_path)
      data = response.body_io.gets_to_end
      File.write("#{download_path}/package.tgz", data)

      # https://github.com/iv-org/invidious/pull/2397#issuecomment-922375908
      if !skip_checksum && `sha1sum #{download_path}/package.tgz`.split(" ")[0] != required_dependencies[dep]["shasum"]
        raise Exception.new("Checksum for '#{dep}' failed")
      end
    end

    # Unless we install an external dependency, crystal provides no way of extracting a tarball.
    # Thus we'll go ahead and call a system command.
    `tar -vzxf '#{download_path}/package.tgz' -C '#{download_path}'`
    raise "Extraction for #{dep} failed" if !$?.success?

    # Would use File.rename in the following steps but for some reason it just doesn't work here.
    # Video.js itself is structured slightly differently
    dep = "video" if dep == "video.js"

    # This dep nests everything under an additional JS or CSS folder
    if dep == "silvermine-videojs-quality-selector"
      js_path = "js/"

      # It also stores their quality selector as `quality-selector.css`
      `mv #{download_path}/package/dist/css/quality-selector.css #{dest_path}/quality-selector.css`
    else
      js_path = ""
    end

    # Would use File.rename but for some reason it just doesn't work here.
    if minified && File.exists?("#{download_path}/package/dist/#{js_path}#{dep}.min.js")
      `mv #{download_path}/package/dist/#{js_path}#{dep}.min.js #{dest_path}/#{dep}.js`
    else
      `mv #{download_path}/package/dist/#{js_path}#{dep}.js #{dest_path}/#{dep}.js`
    end

    # Fetch CSS which isn't guaranteed to exist
    #
    # Also, video JS changes structure here once again...
    dep = "video-js" if dep == "video"

    # VideoJS marker uses a dot on the CSS files.
    dep = "videojs.markers" if dep == "videojs-markers"

    if File.exists?("#{download_path}/package/dist/#{dep}.css")
      if minified && File.exists?("#{download_path}/package/dist/#{dep}.min.css")
        `mv #{download_path}/package/dist/#{dep}.min.css #{dest_path}/#{dep}.css`
      else
        `mv #{download_path}/package/dist/#{dep}.css #{dest_path}/#{dep}.css`
      end
    end

    # Update/create versions file for the dependency
    update_versions_yaml(required_dependencies, minified, dep_name)

    channel.send(dep_name)
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
