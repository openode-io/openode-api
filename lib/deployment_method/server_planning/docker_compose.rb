module DeploymentMethod
  module ServerPlanning
    class DockerCompose < Base
      def self.dind_src_path
        "mkdir -p #{Base::MANAGEMENT_SRC_DIR}deployment/dind-with-docker-compose/"
      end

      def prepare_dind_src(_options = {})
        DockerCompose.dind_src_path
      end

      def apply
        # prepare dind dockerfile folder
        runner.execute([
                         { cmd_name: 'prepare_dind_src' }
                       ])

        # copy dind dockerfile
        # path_dockerfile = File.join(File.dirname(__FILE__), './remote/dind/Dockerfile')
        # remote_path = "#{Base::MANAGEMENT_SRC_DIR}deployment/" \
        #              'dind-with-docker-compose/Dockerfile'
        # runner.upload_content_to(File.read(path_dockerfile), remote_path)
      end
    end
  end
end
