# SPDX-FileCopyrightText: 2019 Omar Roth <omarroth@protonmail.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

macro db_mapping(mapping)
  def initialize({{*mapping.keys.map { |id| "@#{id}".id }}})
  end

  def to_a
      return [ {{*mapping.keys.map { |id| "@#{id}".id }}} ]
  end

  def self.to_type_tuple
      return { {{*mapping.keys.map { |id| "#{id}" }}} }
  end

  DB.mapping( {{mapping}} )
end

macro json_mapping(mapping)
  def initialize({{*mapping.keys.map { |id| "@#{id}".id }}})
  end

  def to_a
      return [ {{*mapping.keys.map { |id| "@#{id}".id }}} ]
  end

  patched_json_mapping( {{mapping}} )
  YAML.mapping( {{mapping}} )
end

macro yaml_mapping(mapping)
  def initialize({{*mapping.keys.map { |id| "@#{id}".id }}})
  end

  def to_a
      return [ {{*mapping.keys.map { |id| "@#{id}".id }}} ]
  end

  def to_tuple
      return { {{*mapping.keys.map { |id| "@#{id}".id }}} }
  end

  YAML.mapping({{mapping}})
end

macro templated(filename, template = "template")
  render "src/invidious/views/#{{{filename}}}.ecr", "src/invidious/views/#{{{template}}}.ecr"
end

macro rendered(filename)
  render "src/invidious/views/#{{{filename}}}.ecr"
end
