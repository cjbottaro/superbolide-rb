require "superbolide/api"

module Superbolide
  module Job

    module ClassMethods

      def superbolide_options(options)
        @superbolide_options = options
      end

      def perform_async(*args)
        Superbolide::Api.enqueue(
          @superbolide_options[:queue],
          self.to_s,
          JSON.dump(args)
        )
      end

    end

    def self.included(mod)
      mod.instance_eval{ @superbolide_options = {queue: "default"} }
      mod.extend(ClassMethods)
    end

  end
end