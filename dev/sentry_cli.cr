require "option_parser"
require "yaml"
require "./sentry"

process_name = nil

begin
  shard_yml = YAML.parse File.read("shard.yml")
  name = shard_yml["name"]?
  process_name = name.as_s if name
rescue e
end

build_args = [] of String
build_command = "crystal build ./src/#{process_name}.cr"
run_args = [] of String
run_command = "./#{process_name}"
files = ["./src/**/*.cr", "./src/**/*.ecr"]
files_cleared = false
show_help = false
should_build = true

OptionParser.parse! do |parser|
  parser.banner = "Usage: ./sentry [options]"
  parser.on(
    "-n NAME",
    "--name=NAME",
    "Sets the name of the app process (current name: #{process_name})") { |name| process_name = name }
  parser.on(
    "-b COMMAND",
    "--build=COMMAND",
    "Overrides the default build command") { |command| build_command = command }
  parser.on(
    "--build-args=ARGS",
    "Specifies arguments for the build command") do |args|
    args_arr = args.strip.split(" ")
    build_args = args_arr if args_arr.size > 0
  end
  parser.on(
    "--no-build",
    "Skips the build step") { should_build = false }
  parser.on(
    "-r COMMAND",
    "--run=COMMAND",
    "Overrides the default run command") { |command| run_command = command }
  parser.on(
    "--run-args=ARGS",
    "Specifies arguments for the run command") do |args|
    args_arr = args.strip.split(" ")
    run_args = args_arr if args_arr.size > 0
  end
  parser.on(
    "-w FILE",
    "--watch=FILE",
    "Overrides default files and appends to list of watched files") do |file|
    unless files_cleared
      files.clear
      files_cleared = true
    end
    files << file
  end
  parser.on(
    "-i",
    "--info",
    "Shows the values for build/run commands, build/run args, and watched files") do
    puts "
      name:       #{process_name}
      build:      #{build_command}
      build args: #{build_args}
      run:        #{run_command}
      run args:   #{run_args}
      files:      #{files}
    "
  end
  parser.on(
    "-h",
    "--help",
    "Show this help") do
    puts parser
    exit 0
  end
end

if process_name
  process_runner = Sentry::ProcessRunner.new(
    process_name: process_name.as(String),
    build_command: build_command,
    run_command: run_command,
    build_args: build_args,
    run_args: run_args,
    should_build: should_build,
    files: files
  )

  process_runner.run
else
  puts "🤖  Sentry error: 'name' not given and not found in shard.yml"
  exit 1
end
