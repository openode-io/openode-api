module DeploymentMethod
  module ServerPlanning
    class Sync < Base
      def sync_mk_src_dir(_opts = {})
        "mkdir -p #{Base::MANAGEMENT_SRC_DIR}api/lib/"
      end

      def apply(_opts = {})
        runner.execute([{ cmd_name: 'sync_mk_src_dir' }])

        # copy sync file
        path_lsync = File.join(File.dirname(__FILE__), './remote/sync/lfiles.js')
        remote_path = "#{Base::MANAGEMENT_SRC_DIR}api/lib/lfiles.js"
        runner.upload_content_to(File.read(path_lsync), remote_path)
      end
    end
  end
end
