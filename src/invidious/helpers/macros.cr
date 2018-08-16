macro add_mapping(mapping)
    def initialize({{*mapping.keys.map { |id| "@#{id}".id }}})
    end

    def to_a
        return [{{*mapping.keys.map { |id| "@#{id}".id }}}]
    end

    DB.mapping({{mapping}})
end

macro templated(filename, template = "template")
    render "src/invidious/views/#{{{filename}}}.ecr", "src/invidious/views/#{{{template}}}.ecr"
end

macro rendered(filename)
    render "src/invidious/views/#{{{filename}}}.ecr"
end
