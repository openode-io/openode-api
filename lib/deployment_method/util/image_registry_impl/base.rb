module DeploymentMethod
  module Util
    module ImageRegistryImpl
      class Base
        attr_accessor :opts

        def initialize(args = {})
          self.opts = args
        end
      end
    end
  end
end
