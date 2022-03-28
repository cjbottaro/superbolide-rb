module Superbolide
  module Job

    module ClassMethods

      def superbolide_options(options)
        @superbolide_options = options
      end

      def perform_async(*args)
        options = @superbolide_options.merge(args: args)
        Superbolide.push(self, options)
      end

    end

    def self.included(mod)
      mod.instance_eval{ @superbolide_options = {} }
      mod.extend(ClassMethods)
    end

  end
end