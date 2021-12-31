require 'dotenv'
require 'base64'

module DeploymentMethod
  class GcloudRun < Base
    KUBECONFIGS_BASE_PATH = "config/kubernetes/"
    CERTS_BASE_PATH = "config/certs/"
    KUBE_TMP_PATH = "/home/tmp/"
    WWW_DEPLOYMENT_LABEL = "www"
    GCLOUD_PROJECT_ID = ENV["GOOGLE_CLOUD_PROJECT"]
    GCP_CERTS_BUCKET = ENV["GCP_CERTS_BUCKET"]
    DEFAULT_MAX_INSTANCES = 1
    EXECUTION_LAYERS = [Website::TYPE_GCLOUD_RUN, Website::TYPE_KUBERNETES].freeze

    def initialize; end

    # verify can deploy

    def verify_can_deploy(options = {})
      super(options)
    end

    def initialization(options = {})
      super(options)
    end

    def instance_up?(_options = {})
      true
    end

    # gcloud cmd

    def gcloud_cmd(options = {})
      website, = get_website_fields(options)
      timeout = options[:timeout] || 400
      chg_dir_workspace = options[:chg_dir_workspace]

      chg_dir_workspace = true if chg_dir_workspace.nil?

      chg_dir_cmd = chg_dir_workspace ? "cd #{website.repo_dir} && " : ""

      "timeout #{timeout} sh -c '#{chg_dir_cmd}gcloud --project #{GCLOUD_PROJECT_ID} " \
      "#{options[:subcommand]}'"
    end

    # kubernetes

    def self.kube_configs
      CloudProvider::Manager.instance.first_details_of_type('gcloud_run')
    end

    def self.kube_configs_at_location(str_id)
      confs = kube_configs

      confs['locations'].find { |l| l['str_id'] == str_id }
    end

    def kubeconfig_path(location)
      location_str_id = location.str_id
      configs = GcloudRun.kube_configs_at_location(location_str_id)

      raise "missing kubeconfig for #{location_str_id}" unless configs

      path = configs['builder_kubeconfig_path']

      assert path

      path
    end

    def load_balancer_ip(location)
      location_str_id = location.str_id
      configs = GcloudRun.kube_configs_at_location(location_str_id)

      raise "missing load_balancer_ip for #{location_str_id}" unless configs

      path = configs['load_balancer_ip']

      assert path

      path
    end

    def kubectl_cmd(options = {})
      assert options[:website_location]
      assert options[:s_arguments]
      website = options[:website_location].website

      config_path = kubeconfig_path(options[:website_location].location)

      namespace = options[:with_namespace] ? "-n #{namespace_of(website)} " : ""

      "KUBECONFIG=#{config_path} kubectl #{namespace}#{options[:s_arguments]}"
    end

    @@test_kubectl_file_path = nil

    def self.set_kubectl_file_path(kube_file_path)
      @@test_kubectl_file_path = kube_file_path
    end

    def self.yml_remote_file_path(action)
      if !@@test_kubectl_file_path
        tmp_file = Tempfile.new("kubectl-#{action}", KUBE_TMP_PATH)

        tmp_file.path
      else
        @@test_kubectl_file_path
      end
    end

    def kubectl_yml_action(website_location, action, content, opts = {})
      tmp_file_path = GcloudRun.yml_remote_file_path(action)
      runner.upload_content_to(content, tmp_file_path)

      result = nil

      begin
        options_last_retry = opts[:last_trial] ? opts[:options_on_last_retry] : ""

        result = ex('kubectl_cmd', {
          website_location: website_location,
          s_arguments: "#{action}#{opts[:kubectl_options]}#{options_last_retry} " \
                        "-f #{tmp_file_path}"
        }.merge(opts))
      ensure
        ex("delete_files", files: [tmp_file_path])
      end

      result
    end

    def image_tag_url(options = {})
      website, = get_website_fields(options)

      tag_name = DeploymentMethod::Util::InstanceImageManager.tag_name(
        website: website,
        execution_id: runner.execution.id
      )

      "gcr.io/#{GCLOUD_PROJECT_ID}/#{website.site_name}:#{tag_name}"
    end

    def clear_certain_files_prior_build_cmd(options = {})
      website, = get_website_fields(options)
      "cd #{website.repo_dir} ; rm -f .gitignore"
    end

    def build_image(options = {})
      website, website_location = get_website_fields(options)

      parent_execution = runner.execution&.parent_execution

      if parent_execution
        return parent_execution&.obj&.dig('image_name_tag')
      elsif website.reference_website_image.present?
        return website.latest_reference_website_image_tag_address
      end

      image_url = image_tag_url(options)

      # clear some files
      ex("clear_certain_files_prior_build_cmd",
         { website: website, website_location: website_location })

      # build

      notify("info", "Preparing instance image...")

      result_build = ex("gcloud_cmd", {
                          website: website,
                          website_location: website_location,
                          subcommand: "builds submit --tag #{image_url} " \
                          "--gcs-log-dir=gs://builds_logs/"
                        })

      # retrieve the build ID, it looks like:
      # Created
      # [https://.../71a90edd-6cbb-4898-9abf-1a58319df67e]
      line_with_build = result_build[:stderr]
                        .lines.find do |line|
                          line.include?("Created [https://cloudbuild.googleapis.com/")
                        end

      if line_with_build.blank?
        raise "No created build link available"
      end

      build_id = line_with_build[line_with_build.rindex("/") + 1..line_with_build.rindex("]") - 1]

      if build_id.blank? || build_id.size <= 10
        raise "Unable to retrieve the build ID"
      end

      # save the image name tag and build ID
      save_extra_execution_attrib('build_id', build_id)

      # retrieve the logs build
      result = ex("gcloud_cmd", {
                    website: website,
                    website_location: website_location,
                    subcommand: "builds log #{build_id}",
                    ensure_exit_code: 0
                  })

      notify("info", result[:stdout])

      raise "Unable to complete successfully the image build" if result_build[:exit_code] != 0

      image_url
    end

    def service_id(website)
      "instance-#{website.id}"
    end

    def first_safe_json(str)
      result_json = JSON.parse(str)

      result_json.length.positive? ? result_json.first : nil
    end

    def region_of(website_location)
      website_location.location_config["provider_id"]
    end

    # returns the service if available, nil otherwise
    def retrieve_run_service(options = {})
      website, website_location = get_website_fields(options)

      result = ex("gcloud_cmd", options.merge(
                                  subcommand: "run services list " \
                                    "--region=#{region_of(website_location)} " \
                                    "--filter=\"metadata.name=#{service_id(website)}\" " \
                                    "--format=json",
                                  chg_dir_workspace: false
                                ))

      first_safe_json(result[:stdout])
    end

    def server_file_exists_cmd(options = {})
      path = options[:path]
      "ls #{path}"
    end

    def gs_cp_cmd(options = {})
      source = options[:source]
      destination = options[:destination]

      "gsutil cp #{source} #{destination}"
    end

    def sync_file_to_gcp_storage(server_file_path, gstorage_url)
      return if ex("server_file_exists_cmd", path: server_file_path)[:exit_code] != 0

      ex("gs_cp_cmd",
         source: server_file_path,
         destination: gstorage_url)[:exit_code].zero?
    end

    def sync_certs(website, website_location)
      Rails.logger.info("Considering syncing certs for website id #{website.id}")

      website_location.obj ||= {}

      if website.certs.blank?
        website_location.obj["gcloud_ssl_cert_url"] = nil
        website_location.obj["gcloud_ssl_key_url"] = nil
        website_location.save
        return
      end

      Rails.logger.info("Syncing certs for website id #{website.id}")

      # GCP_CERTS_BUCKET
      project_path = website.repo_dir

      # SSL cert
      cert_file_path = "#{project_path}#{website.certs[:cert_path]}"
      cert_gstorage_url = "#{GCP_CERTS_BUCKET}#{website.id}.cert"

      if sync_file_to_gcp_storage(cert_file_path, cert_gstorage_url)
        website_location.obj ||= {}
        website_location.obj["gcloud_ssl_cert_url"] = cert_gstorage_url
        website_location.save
      end

      # SSL key
      cert_file_path = "#{project_path}#{website.certs[:cert_key_path]}"
      cert_gstorage_url = "#{GCP_CERTS_BUCKET}#{website.id}.key"

      if sync_file_to_gcp_storage(cert_file_path, cert_gstorage_url)
        website_location.obj ||= {}
        website_location.obj["gcloud_ssl_key_url"] = cert_gstorage_url
        website_location.save
      end
    end

    def escape_quoted_command_line(value)
      value.to_s.gsub("\"", "\\\"").gsub("'", "''")
    end

    def env_variables(website)
      variables_strings = website.env.keys.map do |variable_name|
        value = escape_quoted_command_line(website.env[variable_name])
        variable = escape_quoted_command_line(variable_name)

        "#{variable}=#{value}"
      end

      variables_strings.join(",")
    end

    def env_variables_configmap(variables)
      vars_s = variables.keys.map do |v|
        "  #{v}: \"#{variables[v].to_s.gsub('\\', '\\\\\\').gsub('"', '\\"')}\""
      end

      vars_s.join("\n")
    end

    def generate_config_map_yml(opts = {})
      <<~END_YML
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: #{opts[:name]}
          namespace: #{opts[:namespace]}
        data:
        #{env_variables_configmap(opts[:variables])}
      END_YML
    end

    def deploy(options = {})
      website, website_location = get_website_fields(options)
      image_url = options[:image_url]

      notify("info", "Deploying instance...")

      result = ex("gcloud_cmd", {
                    website: website,
                    website_location: website_location,
                    chg_dir_workspace: false,
                    subcommand: "run deploy #{service_id(website)} --port=80 " \
          "--image #{image_url} " \
          "--platform managed --region #{region_of(website_location)} " \
          "--allow-unauthenticated --set-env-vars=\"#{env_variables(website)}\" " \
          "--memory=#{website.memory}Mi " \
          "--timeout=30 " \
          "--max-instances=#{DEFAULT_MAX_INSTANCES} "
                  })

      notify("info", "--------------- Instance boot logs ---------------")
      logs_instance = ex_stdout(
        "retrieve_logs_cmd",
        { website: website, website_location: website_location, nb_lines: 20 }
      )
      notify("info", logs_instance)
      notify("info", "--------------------------------------------------")

      unless result[:exit_code].zero?

        result_stderr = (result[:stderr]).to_s
        url_log_index = result_stderr.downcase.index("logs url:")

        if url_log_index
          notify("error", result_stderr.slice(0..(url_log_index - 1)))
        else
          notify("error", result_stderr)
        end

        raise "Unable to deploy the instance with success"
      end

      sync_certs(website, website_location)

      notify("info", "Instance deployed successfully")
    end

    def execution_layer_to_close(website)
      original_exec_layer = website.get_config("EXECUTION_LAYER")
      (EXECUTION_LAYERS - [original_exec_layer]).first
    end

    def launch(options = {})
      website, website_location = get_website_fields(options)

      location_valid =
        website_location.valid_location_plan? && website_location.available_location?

      if website.version == "v3" && !location_valid
        raise 'Invalid location for the selected plan. Make sure to remove your current' \
          ' location and add a location available for that plan.'
      end

      image_url = build_image(options)
      save_extra_execution_attrib('image_name_tag', image_url)

      send("launch_#{website.get_config('EXECUTION_LAYER')}",
           options.merge(image_url: image_url))
    end

    def launch_gcloud_run(options = {})
      website, website_location = get_website_fields(options)
      simplified_options = { website: website, website_location: website_location }

      deploy(options.merge(image_url: options[:image_url]))

      service = retrieve_run_service(simplified_options)

      website_location.load_balancer_synced = false
      website_location.obj ||= {}
      website_location.obj["gcloud_url"] = service["status"]&.dig("url")
      website_location.save!
    end

    def kube_ns(website)
      <<~END_YML
        apiVersion: v1
        kind: Namespace
        metadata:
          name: #{namespace_of(website)}
      END_YML
    end

    def kube_service(website)
      <<~END_YML
        apiVersion: v1
        kind: Service
        metadata:
          name: main-service
          namespace: #{namespace_of(website)}
        spec:
          ports:
          - port: 80
            protocol: TCP
            targetPort: 80
          selector:
            app: www
          type: ClusterIP
      END_YML
    end

    def tabulate(nb_tabs, str)
      str.lines.map do |line|
        "  " * nb_tabs + line.sub("\n", "")
      end
         .join("\n")
    end

    def kube_ingress_rule_body
      "paths:\n" \
      "  - backend:\n" \
      "      service:\n" \
      "        name: main-service\n" \
      "        port: \n" \
      "          number: 80\n" \
      "    path: /\n" \
      "    pathType: ImplementationSpecific"
    end

    def kube_ingress_rule(host)
      <<~END_YML
        - host: #{host}
          #{tabulate 0, 'http:'}
          #{tabulate 1, kube_ingress_rule_body}
      END_YML
    end

    def kube_ingress_rules(website_location)
      domains = website_location.compute_domains

      result = ""

      domains.each do |domain|
        result += "#{kube_ingress_rule(domain)}\n\n"
      end

      result
    end

    def kube_ingress(website, website_location)
      <<~END_YML
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          annotations:
            kubernetes.io/ingress.class: nginx
            nginx.ingress.kubernetes.io/limit-rpm: "6000"
            nginx.ingress.kubernetes.io/proxy-body-size: 100m
            nginx.org/websocket-services: main-service
          name: main-ingress
          namespace: #{namespace_of(website)}
        spec:
          rules:
        #{tabulate 1, kube_ingress_rules(website_location)}
      END_YML
    end

    def kube_deployment(website, image_url)
      <<~END_YML
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: www-deployment
          namespace: #{namespace_of(website)}
        spec:
          selector:
            matchLabels:
              app: www
          strategy:
            type: Recreate
          template:
            metadata:
              labels:
                app: www
                deploymentId: "#{deployment_id}"
            spec:
              containers:
              - image: #{image_url}
                name: www
                envFrom:
                - configMapRef:
                    name: dotenv
                ports:
                - containerPort: 80
                  protocol: TCP
                resources:
                  limits:
                    ephemeral-storage: 100Mi
                    memory: #{website.memory}Mi
                  requests:
                    ephemeral-storage: 100Mi
                    memory: #{website.memory}Mi
              restartPolicy: Always
      END_YML
    end

    def kube_yml(website, website_location, image_url)
      ns = namespace_of(website)
      env = website.env.clone
      env["OPENODE_VERSION"] = website.version

      <<~END_YML
        #{kube_ns(website)}
        ---
        #{kube_service(website)}
        ---
        #{kube_ingress(website, website_location)}
        ---
        #{kube_deployment(website, image_url)}
        ---
        #{generate_config_map_yml(name: 'dotenv', namespace: ns, variables: env)}
      END_YML
    end

    def launch_kubernetes(options = {})
      website, website_location = get_website_fields(options)
      # simplified_options = { website: website, website_location: website_location }
      image_url = options[:image_url]

      kube_yml = kube_yml(website, website_location, image_url)

      result = kubectl_yml_action(website_location, "apply", kube_yml, ensure_exit_code: 0)

      notify("info", result[:stdout])

      website_location.load_balancer_synced = false
      website_location.obj ||= {}
      ip = "http://#{load_balancer_ip(website_location.location)}/"
      website_location.obj["gcloud_url"] = ip
      website_location.save!

      result
    end

    # snapshot

    def make_snapshot(options = {})
      require_fields([:snapshot], options)
      website, website_location = get_website_fields(options)
      snapshot = options[:snapshot]

      # configure snapshot for gcloud
      snapshot.destination_path = snapshot.get_destination_path(".tgz")
      snapshot.url = snapshot.get_url
      snapshot.save

      latest_deployment = website.deployments.last

      raise "No latest deployment available" if latest_deployment.blank?

      latest_build_id = latest_deployment.obj["build_id"]

      # get the latest build details
      snapshot.steps << { name: 'retrieving latest build', result: latest_build_id }

      result = ex("gcloud_cmd", {
                    website: website,
                    website_location: website_location,
                    chg_dir_workspace: false,
                    subcommand: "builds describe #{latest_build_id} --format=json"
                  })
      result_json = JSON.parse(result[:stdout])
      storage_source = result_json.dig("source", "storageSource")

      url_build = "gs://#{storage_source['bucket']}/#{storage_source['object']}"

      result_cp = ex("gs_cp_cmd",
                     source: url_build,
                     destination: snapshot.destination_path)

      raise "Unable to copy the build" unless result_cp[:exit_code].zero?

      snapshot.steps << { name: 'make archive', result: result_cp[:stdout] }

      snapshot.status = Snapshot::STATUS_SUCCEED
    rescue StandardError => e
      Ex::Logger.info(e, 'issue to make the snapshot')

      snapshot.steps << { name: 'fail to complete snapshot', result: e }
      snapshot.status = Snapshot::STATUS_FAILED
    ensure
      snapshot.save
    end

    # logs

    def logs(options = {})
      website, website_location = get_website_fields(options)
      options[:nb_lines] ||= 100

      retrieve_logs_cmd(
        website: website,
        website_location: website_location,
        nb_lines: options[:nb_lines]
      )
    end

    def retrieve_logs_cmd(options = {})
      website, website_location = get_website_fields(options)
      options[:nb_lines] ||= 100

      send("retrieve_logs_#{website.get_config('EXECUTION_LAYER')}_cmd",
           website: website,
           website_location: website_location,
           nb_lines: options[:nb_lines])
    end

    def retrieve_logs_kubernetes_cmd(options = {})
      _, website_location = get_website_fields(options)

      kubectl_cmd(
        website_location: website_location,
        with_namespace: true,
        s_arguments: "logs -l app=www --tail #{options[:nb_lines]}"
      )
    end

    def retrieve_logs_gcloud_run_cmd(options = {})
      website, website_location = get_website_fields(options)

      subcommand = "logging read \"resource.labels.service_name=#{service_id(website)}\" " \
        "--format=\"value(textPayload)\" --limit #{options[:nb_lines]}"

      gcloud_cmd({
                   website: website,
                   website_location: website_location,
                   subcommand: subcommand,
                   chg_dir_workspace: false
                 })
    end

    # status

    def status_cmd(options = {})
      website, website_location = get_website_fields(options)

      send("status_#{website.get_config('EXECUTION_LAYER')}_cmd",
           website: website,
           website_location: website_location)
    end

    def status_gcloud_run_cmd(options = {})
      website, website_location = get_website_fields(options)

      gcloud_cmd({
                   website: website,
                   website_location: website_location,
                   subcommand: "run services describe #{service_id(website)} " \
          "--region=#{region_of(website_location)} --format=json",
                   chg_dir_workspace: false
                 })
    end

    def status_kubernetes_cmd(options = {})
      _, website_location = get_website_fields(options)

      kubectl_cmd(
        website_location: website_location,
        with_namespace: true,
        s_arguments: "describe deployment www-deployment"
      )
    end

    # stop

    def delete_service_cmd(options = {})
      website, website_location = get_website_fields(options)
      async = options[:async_argument] || "--no-async"

      gcloud_cmd({
                   website: website,
                   website_location: website_location,
                   chg_dir_workspace: false,
                   subcommand: "run services delete #{service_id(website)} " \
          "--region #{region_of(website_location)} --quiet #{async}"
                 })
    end

    def do_stop(options = {})
      website, = get_website_fields(options)

      send("do_stop_#{website.get_config('EXECUTION_LAYER')}", options)
    end

    def do_stop_gcloud_run(options = {})
      website, website_location = get_website_fields(options)
      async = options[:async_argument] || "--no-async"

      ex("delete_service_cmd",
         {
           website: website,
           website_location: website_location,
           ensure_exit_code: 0,
           default_retry_scheme: true,
           async_argument: async
         })
    end

    def do_stop_kubernetes(options = {})
      website, website_location = get_website_fields(options)

      kube_yml = kube_ns(website)

      result = kubectl_yml_action(website_location, "delete", kube_yml, ensure_exit_code: 0)

      notify("info", result[:stdout])

      result
    end

    def hooks
      [
        GcloudRun.hook_error,
        GcloudRun.hook_verify_can_deploy,
        GcloudRun.hook_logs,
        GcloudRun.hook_finalize,
        GcloudRun.hook_finalize_done,
        GcloudRun.hook_verify_instance_up,
        GcloudRun.hook_verify_instance_up_done
      ]
    end

    def self.gcloud_run_configs
      CloudProvider::Manager.instance.first_details_of_type('gcloud_run')
    end

    def self.gcloud_run_configs_at_location(str_id)
      confs = gcloud_run_configs

      confs['locations'].find { |l| l['str_id'] == str_id }
    end

    def self.configs_at_location(str_id)
      GcloudRun.gcloud_run_configs_at_location(str_id)
    end

    def final_instance_details(opts = {})
      result = {}

      website, website_location = get_website_fields(opts)

      result['result'] = 'success'
      result['url'] = "http://#{website_location.main_domain}/"

      if website.domain_type == 'custom_domain'
        notify('info', 'Custom domain - The DNS documentation is available at ' \
                        'https://www.openode.io/docs/platform/dns.md')

        confs_at = GcloudRun.gcloud_run_configs_at_location(website_location.location.str_id)

        result['CNAME Record'] = confs_at['cname']
      end

      result
    end

    def notify_final_instance_details(opts = {})
      get_website_fields(opts)
      final_details = final_instance_details(opts)

      notify('info', details: final_details)
    end

    def finalize(options = {})
      website, = get_website_fields(options)
      super(options)
      website.reload

      begin
        if website.online?
          notify_final_instance_details(options)
          notify("info", "Please notice that DNS propagation can take few minutes for " \
                "the main URL.")
        else
          # stop it
          notify("info", "Stopping instance...")
          do_stop(options.merge(skip_notify_errors: true, async_argument: "--no-async"))
        end
      rescue StandardError => e
        Ex::Logger.info(e, 'Unable to finalize completely')
      end

      notify('info', "\n\n*** Final Deployment state: #{runner&.execution&.status&.upcase} ***\n")
    end
  end

  class GcloudRunTest < GcloudRun
    attr_accessor :ex_return, :ex_history, :ex_stdout_return, :ex_stdout_history

    def ex(cmd, options = {})
      @ex_history ||= []
      @ex_history << { cmd: cmd, options: options }
      @ind_ex_return ||= -1
      @ind_ex_return += 1

      @ex_return[@ind_ex_return]
    end

    def ex_stdout(cmd, options_cmd = {}, _global_options = {})
      @ex_stdout_history ||= []
      @ex_stdout_history << { cmd: cmd, options: options_cmd }
      @ind_ex_stdout_return ||= -1
      @ind_ex_stdout_return += 1

      @ex_stdout_return[@ind_ex_stdout_return]
    end
  end
end
