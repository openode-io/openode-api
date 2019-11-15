module DeploymentMethod
  module ServerPlanning
    class Nginx < Base
      NGINX_CONFIG_PATH = '/etc/nginx/sites-available/default'

      def cp_original_nginx_configs(_options = {})
        'cp /etc/nginx/nginx.conf.orig /etc/nginx/nginx.conf'
      end

      def restart(_options = {})
        'service nginx restart && service nginx status'
      end

      def self.gen_nginx_http_confs(opts = {})
        "upstream backend-http {\n" +
          opts[:ports].map { |port| "  server 127.0.0.1:#{port};" }.join("\n") +
          "}\n" +
          %(
          server {
                listen       80;
                server_name  #{opts[:domains].join(' ')};
                underscores_in_headers on;

                location / {
                    proxy_http_version 1.1;
                    proxy_pass http://backend-http;
                    proxy_set_header Upgrade $http_upgrade;
                    proxy_set_header Connection "Upgrade";
                    proxy_set_header        X-Forwarded-For   $remote_addr;
                    proxy_set_header        X-Real-IP         $remote_addr;
                    proxy_set_header        Host              $host;
                    proxy_set_header        X-Forwarded-Proto $scheme;
                    proxy_set_header Access-Control-Allow-Origin *;
                    proxy_read_timeout 900;
                }
            }
          )
      end

      def self.gen_nginx_https_confs(opts = {})
        %(
          server {
            server_name  #{opts[:domains].join(' ')};
            underscores_in_headers on;

            listen 443 ssl http2;
            ssl_certificate #{opts[:certs][:cert_path]};
            ssl_certificate_key #{opts[:certs][:cert_key_path]};

            location / {
              proxy_pass http://backendhttp;
              proxy_set_header Upgrade $http_upgrade;
              proxy_set_header Connection "Upgrade";
              proxy_set_header        X-Forwarded-For   $remote_addr;
              proxy_set_header        X-Real-IP         $remote_addr;
              proxy_set_header        Host              $host;
              proxy_set_header        X-Forwarded-Proto $scheme;
              proxy_read_timeout 900;
            }
          }
        )
      end

      def self.gen_nginx_confs(opts = {})
        assert opts[:ports].present?
        assert opts[:domains].present?

        s_confs = Nginx.gen_nginx_http_confs(opts)

        # has ssl? add extra config for HTTPS
        if opts[:certs]
          s_confs += Nginx.gen_nginx_https_confs(opts)
        end

        s_confs
      end

      def apply(opts = {})
        assert opts[:website]
        assert opts[:website_location]

        runner.execute([{ cmd_name: 'cp_original_nginx_configs' }])

        # copy NGINX configs
        domains = opts[:website_location].compute_domains
        nginx_options = {
          domains: domains,
          ports: [opts[:website_location].port, opts[:website_location].second_port],
          certs: opts[:website].certs
        }

        s_nginx_confs = Nginx.gen_nginx_confs(nginx_options)

        runner.upload_content_to(s_nginx_confs, NGINX_CONFIG_PATH)

        # restart NGINX
        runner.execute([{ cmd_name: 'restart' }])
      end
    end
  end
end
