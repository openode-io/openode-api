module DeploymentMethod
  module Util
    class InstanceImageManager
      attr_accessor :runner
      attr_accessor :docker_images_location
      attr_accessor :website
      attr_accessor :deployment

      def initialize(args)
        assert args[:runner]
        assert args[:docker_images_location]
        assert args[:website]
        assert args[:deployment]

        @runner = args[:runner]

        @deployment = args[:deployment]
        @website = args[:website]
        @docker_images_location = args[:docker_images_location]
      end

      def hooks
        []
      end

      def tag_name(options = {})
        "#{options[:website].site_name}--#{options[:website].id}--#{options[:execution_id]}"
      end

      def build_cmd(options = {})
        project_path = options[:project_path]
        repository_name = options[:repository_name] # example: username/reponame

        t_name = tag_name(website: @website, execution_id: @deployment.id)

        "cd #{project_path} && " \
          "docker build -t #{repository_name}:#{t_name} ."
      end

      def push_cmd(options = {})
        repository_name = options[:repository_name]

        t_name = tag_name(website: @website, execution_id: @deployment.id)

        "echo #{docker_images_location['docker_password']} | " \
          "docker login -u #{docker_images_location['docker_username']} " \
          "--password-stdin && " \
          "docker push #{repository_name}:#{t_name}"
      end

      def build
        opts = {
          project_path: @website.repo_dir,
          repository_name:
            "#{docker_images_location['docker_username']}/" \
            "#{docker_images_location['repository_name']}"
        }

        @runner.execute([{ cmd_name: 'build_cmd', options: opts }])
      end

      def push
        opts = {
          repository_name:
            "#{docker_images_location['docker_username']}/" \
            "#{docker_images_location['repository_name']}"
        }

        @runner.execute([{ cmd_name: 'push_cmd', options: opts }])
      end
    end
  end
end
