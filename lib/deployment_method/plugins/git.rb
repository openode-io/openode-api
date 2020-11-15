module DeploymentMethod
  module Plugins
    module Git
      def git_clone(options = {})
        repository_url = runner&.execution&.obj&.dig('with_repository_url')

        return unless repository_url

        notify("info", "git cloning #{repository_url}...")
        options_git_clone = options.merge(repository_url: repository_url, is_complex: false)

        ex("clear_repository", options_git_clone)

        ex("cmd_git_clone", options_git_clone.merge(ensure_exit_code: 0))
        notify("info", "...cloned!")
      end

      def cmd_git_clone(options = {})
        website, = get_website_fields(options)
        "git clone #{options[:repository_url]} #{website.repo_dir}"
      end
    end
  end
end
