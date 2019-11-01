module DeploymentMethod
  module ServerPlanning
    class Base
      attr_accessor :runner

      MANAGEMENT_SRC_DIR = '/root/openode-www/'

      # def initialize(runner)
      #  self.runner = runner
      # end

      def apply
        raise 'not implemented'
      end
    end
  end
end
