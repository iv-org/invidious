abstract class Invidious::Jobs::BaseJob
  abstract def begin

  # When this base job class is inherited, make sure to define
  # a basic "Config" structure, that contains the "enable" property,
  # and to create the associated instance property.
  #
  macro inherited
    macro finished
      # This config structure can be expanded as required.
      struct Config
        include YAML::Serializable

        property enable = true

        def initialize
        end
      end

      property cfg = Config.new

      # Return true if job is enabled by config
      protected def enabled? : Bool
        return (@cfg.enable == true)
      end

      # Return true if job is disabled by config
      protected def disabled? : Bool
        return (@cfg.enable == false)
      end
    end
  end
end
