require "../spec_helper"
require "../../src/invidious/jobs.cr"
require "../../src/invidious/jobs/*"
require "../../src/invidious/config.cr"
require "../../src/invidious/user/preferences.cr"

# Allow this file to be executed independently of other specs
{% if !@type.has_constant?("CONFIG") %}
  CONFIG = Config.from_yaml("")
{% end %}

private def construct_config(yaml)
  config = Config.from_yaml(yaml)
  File.open(File::NULL, "w") { |io| config.process_deprecation(io) }
  return config
end

Spectator.describe Config do
  context "page_enabled" do
    it "Can disable pages" do
      config = construct_config <<-YAML
        pages_enabled:
          popular: false
          search: false
      YAML

      expect(config.page_enabled?("trending")).to eq(false)
      expect(config.page_enabled?("popular")).to eq(false)
      expect(config.page_enabled?("search")).to eq(false)
    end

    it "Takes precedence over popular_enabled" do
      config = construct_config <<-YAML
        popular_enabled: false
        pages_enabled:
          popular: true
      YAML

      expect(config.page_enabled?("popular")).to eq(true)
    end
  end

  it "Deprecated popular_enabled still works" do
    config = construct_config <<-YAML
      popular_enabled: false
    YAML

    expect(config.page_enabled?("popular")).to eq(false)
  end
end
