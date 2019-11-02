module DeploymentMethod
  module ServerPlanning
    class DockerCompose < Base
      def self.dind_mk_src_dir
        "mkdir -p #{Base::MANAGEMENT_SRC_DIR}deployment/dind-with-docker-compose/"
      end

      def prepare_dind_src(_options = {})
        DockerCompose.dind_mk_src_dir
      end

      def apply(_opts = {})
        # prepare dind dockerfile folder
        runner.execute([
                         { cmd_name: 'prepare_dind_src' }
                       ])

        # copy dind dockerfile
        path_dockerfile = File.join(File.dirname(__FILE__), './remote/dind/Dockerfile')
        remote_path = "#{Base::MANAGEMENT_SRC_DIR}deployment/" \
                      'dind-with-docker-compose/Dockerfile'
        runner.upload_content_to(File.read(path_dockerfile), remote_path)
      end
    end
  end
end
