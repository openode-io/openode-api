module DeploymentMethod
  module Util
    class InstanceImageManager
      attr_accessor :runner, :docker_images_location, :website, :deployment

      LIMIT_REPOSITORY_BYTES = 1024 * 1024 * 1024 # MB * KB * B -> 1 GB
      MAX_BUILD_TIMEOUT = 360
      TIMEOUT_EXIT_CODE = 124
      TAG_NAME_SEPARATOR = '--'

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

      def self.tag_name(options = {})
        "#{options[:website].site_name}#{TAG_NAME_SEPARATOR}#{options[:website].id}" \
        "#{TAG_NAME_SEPARATOR}#{options[:execution_id]}"
      end

      # given a tag name, retrieve the parts
      def self.tag_parts(tag_name)
        tag_parts = tag_name.split(TAG_NAME_SEPARATOR)

        return {} if tag_parts.length != 3

        {
          site_name: tag_parts.first,
          website_id: tag_parts[1],
          execution_id: tag_parts.last
        }
      end

      def image_name_tag
        t_name = InstanceImageManager.tag_name(website: @website, execution_id: @deployment.id)
        "#{full_repository_name}/#{@website.site_name}:#{t_name}"
      end

      def full_repository_name
        "#{docker_images_location['docker_server']}/" \
        "#{docker_images_location['repository_name']}"
      end

      def build_cmd(options = {})
        project_path = options[:project_path]

        "cd #{project_path} && " \
        "sudo timeout #{MAX_BUILD_TIMEOUT}s docker build -t #{image_name_tag} ."
      end

      def push_cmd(_options = {})
        "echo #{docker_images_location['docker_password']} | " \
          "sudo docker login -u #{docker_images_location['docker_username']} " \
          "#{docker_images_location['docker_server']} " \
          "--password-stdin && " \
          "sudo docker push #{image_name_tag}"
      end

      def verify_size_repo_cmd(options = {})
        project_path = options[:project_path]

        "du -bs #{project_path}"
      end

      def verify_size_repo
        opts = {
          project_path: @website.repo_dir
        }

        result = @runner.execute([{ cmd_name: 'verify_size_repo_cmd', options: opts }])

        ensure_no_execution_error("verifying repository size", result.first)

        output = result[0][:result][:stdout] rescue ''
        nb_bytes = output.to_i

        err_msg_too_large = "Repository image size is too large " \
          "(limit = #{LIMIT_REPOSITORY_BYTES} bytes)"
        raise err_msg_too_large if nb_bytes > LIMIT_REPOSITORY_BYTES
      end

      def ensure_no_execution_error(step_name, result)
        unless result[:result][:exit_code].zero?
          specific_msg = if result[:result][:exit_code] == TIMEOUT_EXIT_CODE
                           "\nFATAL: Docker timeout reached (#{MAX_BUILD_TIMEOUT} seconds)"
          end

          msg = "Failed at #{step_name}. \n#{result.dig(:result, :stdout)}" \
                " \n#{result.dig(:result, :stderr)}, " \
                "exit code = #{result[:result][:exit_code]}" \
                "#{specific_msg}"
          raise msg + OutputDiagnostic.analyze("build_image", msg)
        end
      end

      def build
        opts = {
          project_path: @website.repo_dir
        }

        result = @runner.execute([{ cmd_name: 'build_cmd', options: opts }])

        ensure_no_execution_error("building the image", result.first)

        result
      end

      def push
        opts = {
          repository_name:
            "#{docker_images_location['docker_username']}/" \
            "#{docker_images_location['repository_name']}"
        }

        Ex::Retry.n_times(nb_trials: 3, sleep_n: 2) do
          result = @runner.execute([{ cmd_name: 'push_cmd', options: opts }])

          ensure_no_execution_error("pushing the image", result.first)

          result
        end
      end
    end
  end
end
