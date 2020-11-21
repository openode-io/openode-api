module DeploymentMethod
  module Plugins
    module OpenodeCli
      def openode_cli_template(options = {})
        website = options[:website]

        "cd #{website.repo_dir} ; openode template"
      end
    end
  end
end
