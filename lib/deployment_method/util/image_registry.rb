module DeploymentMethod
  module Util
    class ImageRegistry
      def self.instance(type, args = {})
        klass = "DeploymentMethod::Util::ImageRegistryImpl::#{type.camelize}".constantize

        klass.new(args)
      end
    end
  end
end
