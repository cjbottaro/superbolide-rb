module Superbolide
  module Job

    module ClassMethods

      def superbolide_options(options)
        @superbolide_options = options
      end

      def perform_async(*args)
        job = {
          queue: @superbolide_options[:queue],
          payload: JSON.dump(args),
          type: self.to_s
        }

        Superbolide.enqueue(job)
      end

    end

    def self.included(mod)
      mod.instance_eval{ @superbolide_options = {queue: "default"} }
      mod.extend(ClassMethods)
    end

  end
end