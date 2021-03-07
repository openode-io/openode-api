
module DeploymentMethod
  module Plugins
    module DirectTemplate
      def direct_template_init(options = {})
        website = options[:website]

        app = website.active_one_click_app

        return unless app

        dockerfile = direct_template_finalize_dockerfile(app.dockerfile, website.one_click_app)

        runner.upload_content_to(dockerfile,
                                 "#{website.repo_dir}Dockerfile")
      end

      def direct_template_finalize_dockerfile(dockerfile, one_click_options = {})
        lines = dockerfile.lines
        first_line = lines.first.strip
        lines.shift

        return dockerfile unless first_line

        return dockerfile if first_line.include?(":")

        return dockerfile unless one_click_options['version']

        (["#{first_line}:#{one_click_options['version']}"] + lines).join("\n")
      end
    end
  end
end
