module DeploymentMethod
  module ServerPlanning
    class Nginx < Base
      def cp_original_nginx_configs(_options = {})
        'cp /etc/nginx/nginx.conf.orig /etc/nginx/nginx.conf'
      end

      def self.gen_nginx_confs(opts = {})
        'upstream backend-http {\n' +
          opts[:ports].map { |port| "  server 127.0.0.1:#{port};" }.join('\n') +
          '}'
      end

      def apply(opts = {})
        assert opts[:website]
        assert opts[:website_location]

        domains = opts[:website_location].compute_domains
        nginx_options = {
          domains: domains,
          ports: [opts[:website_location].port, opts[:website_location].second_port],
          certs: opts[:website].certs
        }

        Nginx.gen_nginx_confs(nginx_options)

        runner.execute([
                         { cmd_name: 'cp_original_nginx_configs' }
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
