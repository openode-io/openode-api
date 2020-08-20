require 'dotenv'
require 'base64'

module DeploymentMethod
  class Kubernetes < Base
    KUBECONFIGS_BASE_PATH = "config/kubernetes/"
    CERTS_BASE_PATH = "config/certs/"
    KUBE_TMP_PATH = "/home/tmp/"

    def initialize; end

    # verify can deploy

    def verify_can_deploy(options = {})
      super(options)
    end

    def initialization(options = {})
      super(options)

      send_crontab(options)
    end

    def self.kube_configs
      CloudProvider::Manager.instance.first_details_of_type('kubernetes')
    end

    def self.kube_configs_at_location(str_id)
      confs = kube_configs

      confs['locations'].find { |l| l['str_id'] == str_id }
    end

    def send_crontab(options = {})
      super(options)
    end

    def cmd_docker_registry_secret(website, docker_images_location)
      " -n #{namespace_of(website)} " \
      "create secret docker-registry regcred " \
      "--docker-server=#{docker_images_location['docker_server']} " \
      "--docker-username=#{docker_images_location['docker_username']} " \
      "--docker-password=#{docker_images_location['docker_password']} " \
      "--docker-email=#{docker_images_location['docker_email']} "
    end

    def make_docker_registry_secret(website, website_location, docker_images_location)
      registry_secret_cmd_arguments =
        cmd_docker_registry_secret(website, docker_images_location)

      ex_stdout('kubectl',
                website_location: website_location,
                s_arguments: registry_secret_cmd_arguments)
    end

    def prepare_image_manager(website, website_location)
      cloud_provider_manager = CloudProvider::Manager.instance
      img_location = cloud_provider_manager.docker_images_location

      # ensure docker registry secret
      make_docker_registry_secret(website, website_location, img_location)

      # build the image
      cloned_runner = runner.clone
      image_manager = DeploymentMethod::Util::InstanceImageManager.new(
        runner: runner,
        docker_images_location: img_location,
        website: website,
        deployment: runner.execution
      )

      cloned_runner.set_execution_method(image_manager)

      image_manager
    end

    def initialize_ns(options = {})
      website, website_location = get_website_fields(options)

      ex_stdout('kubectl',
                website_location: website_location,
                s_arguments: "create namespace #{namespace_of(website)}")
    end

    def prepare_image_name_tag(website, website_location, parent_execution)
      image_manager = prepare_image_manager(website, website_location)

      if parent_execution
        parent_execution&.obj&.dig('image_name_tag')
      elsif website.reference_website_image.present?
        website.latest_reference_website_image_tag_address
      else
        notify("info", "Preparing instance image...")
        image_manager.verify_size_repo
        result_build = image_manager.build
        notify("info", result_build.first&.dig(:result, :stdout)) if result_build&.first
        notify("info", "Instance image ready.")

        # then push it to the registry
        notify("info", "Pushing instance image...")
        image_manager.push
        notify("info", "Instance image pushed successfully.")

        image_manager.image_name_tag
      end
    end

    def launch(options = {})
      website, website_location = get_website_fields(options)

      initialize_ns(options) unless options[:skip_initialize_ns]

      image_name_tag = prepare_image_name_tag(website, website_location,
                                              runner.execution&.parent_execution)

      raise 'Missing instance image build' unless image_name_tag

      # save the image name tag
      save_extra_execution_attrib('image_name_tag', image_name_tag)

      # generate the yml to the build machine
      kube_yml = generate_instance_yml(website, website_location,
                                       with_namespace_object: true,
                                       with_pvc_object: true,
                                       image_name_tag: image_name_tag)

      notify("info", "Applying instance environment...")

      # then apply the yml
      result = kubectl_yml_action(website_location, "apply", kube_yml, ensure_exit_code: 0)

      notify("info", result[:stdout])

      result
    end

    def should_remove_namespace?(website)
      !website.extra_storage?
    end

    # stop
    def do_stop(options = {})
      website, website_location = get_website_fields(options)

      image_manager = prepare_image_manager(website, website_location)

      # the namespace object must not be generated, as we want to keep it,
      # to make sure for instance persitent objects are not destroyed
      with_namespace_object = should_remove_namespace?(website.reload)
      kube_yml = generate_instance_yml(website, website_location,
                                       with_namespace_object: with_namespace_object,
                                       with_pvc_object: false,
                                       image_name_tag: image_manager.image_name_tag)
      # then delete the yml
      kubectl_yml_action(website_location, "delete", kube_yml,
                         default_retry_scheme: true,
                         skip_notify_errors: options[:skip_notify_errors])
    end

    def make_archive(options = {})
      require_fields([:archive_path], options)
      require_fields([:folder_path], options)

      "cd #{options[:folder_path]} && " \
      "zip -r #{options[:archive_path]} . ; " \
      "rm -rf #{options[:folder_path]}"
    end

    def make_snapshot(options = {})
      require_fields([:snapshot], options)
      website, website_location = get_website_fields(options)
      snapshot = options[:snapshot]

      # copy instance files
      result = ex('kubectl_on_latest_pod',
                  website: website,
                  website_location: website_location,
                  s_arguments: "cp POD_NAME:#{snapshot.path} #{snapshot.get_destination_folder}",
                  pod_name_delimiter: "POD_NAME")
      snapshot.steps << { name: 'copy instance files', result: result }

      # make an archive
      result_archive = ex('make_archive',
                          archive_path: snapshot.get_destination_path(".zip"),
                          folder_path: snapshot.get_destination_folder)
      snapshot.steps << { name: 'make archive', result: result_archive }

      snapshot.status = Snapshot::STATUS_SUCCEED
    rescue StandardError => e
      Ex::Logger.info(e, 'issue to make the snapshot')

      snapshot.steps << { name: 'fail to complete snapshot', result: e }
      snapshot.status = Snapshot::STATUS_FAILED
    ensure
      snapshot.save
    end

    def reload(options = {})
      website = options[:website]

      if website.reference_website_image.blank?
        runner.execution.parent_execution_id = website.deployments.success.last&.id
        runner.execution.save
      end

      result = launch((options || {}).merge(skip_initialize_ns: true))

      runner.execution.status = Execution::STATUS_SUCCESS
      runner.execution.save

      result
    rescue StandardError => e
      notify("error", "Failed, #{e}")
      runner.execution.status = Execution::STATUS_FAILED
      runner.execution.save

      { result: "Failed, error: #{e}" }
    end

    def kubectl(options = {})
      assert options[:website_location]
      assert options[:s_arguments]
      website = options[:website_location].website

      config_path = kubeconfig_path(options[:website_location].location)

      namespace = options[:with_namespace] ? "-n #{namespace_of(website)} " : ""

      cmd = "KUBECONFIG=#{config_path} kubectl #{namespace}#{options[:s_arguments]}"
      cmd
    end

    def raw_kubectl(options = {})
      assert options[:s_arguments]

      config_path = kubeconfig_path(options[:location] || location)

      cmd = "KUBECONFIG=#{config_path} kubectl #{options[:s_arguments]}"
      cmd
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
      tmp_file_path = Kubernetes.yml_remote_file_path(action)
      runner.upload_content_to(content, tmp_file_path)

      result = nil

      begin
        result = ex('kubectl', {
          website_location: website_location,
          s_arguments: "#{action} -f #{tmp_file_path}"
        }.merge(opts))
      ensure
        ex("delete_files", files: [tmp_file_path])
      end

      result
    end

    def retrieve_file_cmd(options = {})
      assert options[:path]

      "cat #{options[:path]}"
    end

    def retrieve_dotenv_cmd(options = {})
      website = options[:website]

      project_path = website.repo_dir
      dotenv_relative_filepath = website.dotenv_filepath

      retrieve_file_cmd(path: "#{project_path}#{dotenv_relative_filepath}")
    end

    def retrieve_remote_file(options = {})
      assert options[:cmd]
      assert options[:name]
      assert options[:website]

      result = if runner.execution&.parent_execution
                 # if there is a parent execution, we get the content from the saved vault
                 runner.execution&.parent_execution&.secret&.dig(options[:name].to_sym) || ""
               elsif options[:website].reference_website_image.present?
                 # we are referenced to the last execution of a website
                 latest_deployment = options[:website]&.latest_reference_website_image_deployment
                 latest_deployment&.secret&.dig(options[:name].to_sym) || ""
               else
                 ex(options[:cmd], options)[:stdout]
      end

      store_remote_file(options[:name], result)

      result
    end

    def prepare_dotenv_hash(website, dotenv_file_content)
      env_from_file = Dotenv::Parser.call(dotenv_file_content || '')

      stored_env = website.env

      env_from_file.merge(stored_env)
    end

    def retrieve_dotenv(website)
      dotenv_content = retrieve_remote_file(
        name: 'dotenv',
        cmd: "retrieve_dotenv_cmd",
        website: website
      )

      prepare_dotenv_hash(website, dotenv_content)
    end

    def dotenv_vars_to_s(variables)
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
        #{dotenv_vars_to_s(opts[:variables])}
      END_YML
    end

    def generate_instance_yml(website, website_location, opts = {})
      assert !opts[:with_namespace_object].nil?
      assert !opts[:with_pvc_object].nil?
      dotenv_vars = retrieve_dotenv(website)

      <<~END_YML
        ---
        #{generate_namespace_yml(website) if opts[:with_namespace_object]}
        ---
        #{generate_persistence_volume_claim_yml(website_location) if opts[:with_pvc_object]}
        ---
        #{generate_manual_tls_secret_yml(website)}
        ---
        #{generate_wildcard_subdomain_tls_secret_yaml(website, website_location) if website.subdomain?}
        ---
        #{generate_config_map_yml(
          name: 'dotenv',
          namespace: namespace_of(website),
          variables: dotenv_vars
        )}
        ---
        #{generate_deployment_yml(website, website_location, opts)}
        ---
        #{generate_deployment_addons_yml([0])}
        ---
        #{generate_service_yml(website)}
        ---
        #{generate_ingress_yml(website, website_location)}
        ---
      END_YML
    end

    def namespace_of(website = nil)
      "instance-#{website&.id}"
    end

    def website_from_namespace(namespace)
      parts = namespace.split('-')

      Website.find_by id: parts.second
    end

    def generate_namespace_yml(website)
      <<~END_YML
        apiVersion: v1
        kind: Namespace
        metadata:
          name: #{namespace_of(website)}
      END_YML
    end

    def generate_persistence_volume_claim_yml(website_location)
      return '' unless website_location.extra_storage?

      kube_cloud = Kubernetes.kube_configs
      storage_class_name = kube_cloud['storage_class_name']

      <<~END_YML
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: main-pvc
          namespace: #{namespace_of(website_location.website)}
        spec:
          accessModes:
            - ReadWriteOnce
          resources:
            requests:
              storage: #{website_location.extra_storage}Gi
          storageClassName: #{storage_class_name}
      END_YML
    end

    def destroy_storage_cmd(options = {})
      _, website_location = get_website_fields(options)

      args = {
        website_location: website_location,
        with_namespace: true,
        s_arguments: "delete pvc main-pvc"
      }

      kubectl(args)
    end

    def generate_deployment_probes_yml(opts = {})
      return '' unless opts[:with_readiness_probe]

      # livenessProbe:
      #    httpGet:
      #      path: #{website.status_probe_path}
      #      port: 80
      #    initialDelaySeconds: 120
      #    periodSeconds: 600
      #    timeoutSeconds: 3
      #    failureThreshold: 1

      <<~END_YML
        readinessProbe:
          httpGet:
            path: #{opts[:status_probe_path]}
            port: 80
          periodSeconds: #{opts[:status_probe_period]}
          initialDelaySeconds: 10
      END_YML
    end

    def storage_volumes?(website, website_location)
      website_location.extra_storage? && website.storage_areas && !website.storage_areas.empty?
    end

    def generate_deployment_mount_paths_yml(website, website_location)
      return "" unless storage_volumes?(website, website_location)

      yml = ""

      website.storage_areas.each do |storage_path|
        yml += "" \
"        - mountPath: \"#{storage_path}\"\n"\
"          name: main-volume\n"
      end

      yml
    end

    def generate_deployment_volumes_yml(website, website_location)
      return "" unless storage_volumes?(website, website_location)

      chmod_cmds = website.storage_areas.map { |a| "chmod 777 \"#{a}\"" }.join(" ; ")

      yml = "" \
"      volumes:\n" \
"      - name: main-volume\n" \
"        persistentVolumeClaim:\n" \
"          claimName: main-pvc\n" \
"      initContainers:\n" \
"      - name: init-volume\n" \
"        image: busybox\n" \
"        command: ['sh', '-c', '#{chmod_cmds}']\n" \
"        volumeMounts:\n"

      yml + generate_deployment_mount_paths_yml(website, website_location)
    end

    def deployment_strategy(website, memory)
      kube_cloud = Kubernetes.kube_configs
      attr_limit_memory = 'limit_memory_for_rolling_update_strategy'
      limit_mem_rolling_update = kube_cloud[attr_limit_memory]

      raise "Missing #{attr_limit_memory}" if limit_mem_rolling_update.blank?

      if memory <= limit_mem_rolling_update || website.blue_green_deployment?
        "RollingUpdate"
      else
        "Recreate"
      end
    end

    def tabulate(nb_tabs, str)
      str.lines.map do |line|
        "  " * nb_tabs + line.sub("\n", "")
      end
         .join("\n")
    end

    def generate_deployment_yml(website, website_location, opts)
      deployment_probes = generate_deployment_probes_yml(
        with_readiness_probe: !website.skip_port_check?,
        status_probe_path: website.status_probe_path,
        status_probe_period: website.status_probe_period
      )

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
          replicas: #{website_location.replicas}
          strategy:
            type: #{deployment_strategy(website, website.memory)}
          template:
            metadata:
              labels:
                app: www
                deploymentId: "#{deployment_id}"
            spec:
              imagePullSecrets:
              - name: regcred
        #{generate_deployment_volumes_yml(website, website_location)}
              containers:
              - image: #{opts[:image_name_tag]}
                imagePullPolicy: Always
                name: www
                envFrom:
                - configMapRef:
                    name: dotenv
                ports:
                - containerPort: 80
        #{tabulate 4, deployment_probes}
                resources:
                  limits: # more resources if available in the cluster
                    ephemeral-storage: 100Mi
                    memory: #{website.memory}Mi
                    # cpu: #{website.cpus}
                  requests:
                    ephemeral-storage: 100Mi
                    memory: #{website.memory}Mi
                    # cpu: #{website.cpus}
                #{'volumeMounts:  ' if storage_volumes?(website, website_location)}
        #{generate_deployment_mount_paths_yml(website, website_location)}
      END_YML
    end

    def generate_deployment_addons_yml(addons)
      addons
        .map { |addon| generate_deployment_addon_yml(addon) }
        .join("\n---")
    end

    def generate_deployment_addon_yml(_addon)
      <<~END_YML
        apiVersion: v1
        kind: Service
        metadata:
          name: redis
          namespace: instance-167
        spec:
          type: NodePort
          ports:
          - port: 6379
            targetPort: 6379
            protocol: TCP
          selector:
            app: redis
        ---
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: redis-deployment
          namespace: instance-167
        spec:
          selector:
            matchLabels:
              app: redis
          replicas: 1
          strategy:
            type: "Recreate"
          template:
            metadata:
              labels:
                app: redis
            spec:
              containers:
              - image: redis
                imagePullPolicy: Always
                name: redis
                envFrom:
                - configMapRef:
                    name: dotenv
                ports:
                - containerPort: 6379
                resources:
                  limits: # more resources if available in the cluster
                    ephemeral-storage: 100Mi
                    memory: 100Mi
                  requests:
                    ephemeral-storage: 100Mi
                    memory: 100Mi
      END_YML
    end

    def generate_service_yml(website)
      <<~END_YML
        apiVersion: v1
        kind: Service
        metadata:
          name: main-service
          namespace: #{namespace_of(website)}
        spec:
          type: NodePort
          ports:
          - port: 80
            targetPort: 80
            protocol: TCP
          selector:
            app: www
      END_YML
    end

    def certificate?(website)
      website.certs.present? || website.subdomain?
    end

    def certificate_secret_name(website)
      if website.certs.present?
        "manual-certificate"
      elsif website.subdomain?
        "wildcard-certificate"
      end
    end

    def generate_tls_secret_yml(website, opts = {})
      require_fields([:name, :crt, :key], opts)

      <<~END_YML
        apiVersion: v1
        kind: Secret
        metadata:
          name: #{opts[:name]}
          namespace: #{namespace_of(website)}
        type: kubernetes.io/tls
        data:
          tls.crt: #{Base64.strict_encode64(opts[:crt])}
          tls.key: #{Base64.strict_encode64(opts[:key])}
      END_YML
    end

    def generate_manual_tls_secret_yml(website)
      return "" if website.certs.blank?

      crt = retrieve_remote_file(
        name: 'cert_crt',
        cmd: "retrieve_file_cmd",
        ensure_exit_code: 0,
        path: "#{website.repo_dir}#{website.certs[:cert_path]}",
        website: website
      )

      crt_key = retrieve_remote_file(
        name: 'cert_key',
        cmd: "retrieve_file_cmd",
        ensure_exit_code: 0,
        path: "#{website.repo_dir}#{website.certs[:cert_key_path]}",
        website: website
      )

      generate_tls_secret_yml(website,
                              name: certificate_secret_name(website),
                              crt: crt,
                              key: crt_key)
    end

    def generate_wildcard_subdomain_tls_secret_yaml(website, website_location)
      location_str_id = website_location.location.str_id

      wildcard_crt_path =
        Rails.root.join("#{CERTS_BASE_PATH}#{ENV['RAILS_ENV']}-wildcard-#{location_str_id}.crt")
      wildcard_key_path =
        Rails.root.join("#{CERTS_BASE_PATH}#{ENV['RAILS_ENV']}-wildcard-#{location_str_id}.key")

      return "" if !File.exist?(wildcard_crt_path) || !File.exist?(wildcard_key_path)

      crt = IO.read(wildcard_crt_path)
      key = IO.read(wildcard_key_path)

      generate_tls_secret_yml(website,
                              name: certificate_secret_name(website),
                              crt: crt,
                              key: key)
    end

    def generate_rules_ingress_yml(website, _website_location, rules = [])
      if website.subdomain?
        # disabled.. cleanup
        # we add an extra rule:
        # - host: ***.k8s.ovh.net # nginx controller external ip

        # TODO: - should really remove?
        # load_balancer = find_first_load_balancer!(default_services)
        # rules << { hostname: load_balancer }
      end

      result = ""

      rules.each do |rule|
        result += "    - host: #{rule[:hostname]}\n" \
                  "      http:\n" \
                  "        paths:\n" \
                  "        - path: /\n" \
                  "          backend:\n" \
                  "            serviceName: main-service\n" \
                  "            servicePort: 80\n"
      end

      result
    end

    def generate_tls_specs_ingress_yml(website, rules = [])
      result = "  tls:\n" \
               "  - hosts:\n"

      spec_rules = rules.clone

      spec_rules << spec_rules[0]

      spec_rules.each do |rule|
        result += "    - #{rule[:hostname]}\n"
      end

      result += "    secretName: #{certificate_secret_name(website)}"

      result
    end

    def generate_ingress_yml(website, website_location)
      domains = website_location.compute_domains
      rules_domains = domains.map { |d| { hostname: d } }

      <<~END_YML
        apiVersion: extensions/v1beta1
        kind: Ingress
        metadata:
          name: main-ingress
          namespace: #{namespace_of(website)}
          annotations:
            kubernetes.io/ingress.class: "nginx"
            nginx.org/websocket-services: "main-service"
            nginx.org/client-max-body-size: "100m"
            ingress.kubernetes.io/ssl-redirect: "#{website.get_config('REDIR_HTTP_TO_HTTPS')}"
            # cert-manager.io/cluster-issuer: "letsencrypt-prod"
        spec:
        #{generate_tls_specs_ingress_yml(website, rules_domains) if certificate?(website)}
          rules:
        #{generate_rules_ingress_yml(website, website_location, rules_domains)}
      END_YML
    end

    def node_available?(options = {})
      _, website_location = get_website_fields(options)

      kubectl_args = {
        website_location: website_location,
        with_namespace: true,
        s_arguments: "get pods " \
          "-o=jsonpath='{.items[*].status.containerStatuses[*].state.waiting}' " \
          "| grep \"CrashLoopBackOff\"" # There should NOT be any container in
        # crash loop backoff state
      }

      result = ex("kubectl", kubectl_args)

      result[:exit_code] == 1
    end

    def instance_up_cmd(options = {})
      _, website_location = get_website_fields(options)

      args = {
        website_location: website_location,
        with_namespace: true,
        s_arguments: "get pods " \
          "-o=jsonpath='{.items[*].status.containerStatuses[*].ready}' " \
          "| grep -v false" # There should NOT be any container not ready
      }

      kubectl(args)
    end

    def get_pods_json(options = {})
      _, website_location = get_website_fields(options)

      args = {
        website_location: website_location,
        with_namespace: true,
        s_arguments: "get pods -o json",
        default_retry_scheme: true,
        ensure_exit_code: 0
      }

      JSON.parse(ex("kubectl", args)[:stdout])
    end

    def get_services_json(options = {})
      _, website_location = get_website_fields(options)

      args = {
        website_location: website_location,
        with_namespace: options[:with_namespace],
        s_arguments: "get services -o json",
        default_retry_scheme: true,
        ensure_exit_code: 0
      }

      JSON.parse(ex("kubectl", args)[:stdout])
    end

    def ex_on_all_pods_stdout(_cmd, options = {})
      pods_result = get_pods_json(options)

      pods_result.dig('items').map do |pod|
        pod_name = pod.dig('metadata', 'name')

        {
          name: pod_name,
          result: ex_stdout('custom_cmd',
                            options.merge(
                              cmd: "cat /proc/net/dev",
                              pod_name: pod_name
                            ))
        }
      end
    end

    def find_first_load_balancer(object)
      load_balancer = nil

      object['items'].each do |item|
        next unless item.dig('spec', 'type') == "LoadBalancer"

        in_load_balancers = item.dig('status', 'loadBalancer', 'ingress')

        if in_load_balancers
          load_balancer =
            in_load_balancers[0]['hostname'] || in_load_balancers[0]['ip']
        end
      end

      load_balancer
    end

    # if not found, throw an exception
    def find_first_load_balancer!(object)
      result = find_first_load_balancer(object)

      raise 'Cannot find a proper load balancer' unless result

      result
    end

    def get_latest_pod_in(pods_json)
      return nil if !pods_json || !pods_json['items']

      pods_json['items'].max_by do |pod|
        Time.zone.parse(pod['metadata']['creationTimestamp'])
      end
    end

    def get_latest_pod_name_in(pods_json)
      get_latest_pod_in(pods_json)['metadata']['name']
    end

    def kubectl_on_latest_pod(options = {})
      website, website_location = get_website_fields(options)
      require_fields([:s_arguments, :pod_name_delimiter], options)

      pod_name = options[:pod_name]

      unless pod_name
        pods = get_pods_json(
          website: website,
          website_location: website_location
        )

        pod_name = get_latest_pod_name_in(pods)
      end

      args = {
        website_location: website_location,
        with_namespace: true,
        s_arguments: options[:s_arguments].gsub(options[:pod_name_delimiter], pod_name)
      }

      kubectl(args)
    end

    def logs(options = {})
      website, website_location = get_website_fields(options)
      options[:nb_lines] ||= 100

      args = {
        website: website,
        website_location: website_location,
        with_namespace: true,
        s_arguments: "logs -l app=www --tail=#{options[:nb_lines]}"
      }

      kubectl(args)
    end

    def custom_cmd(options = {})
      website, website_location = get_website_fields(options)
      cmd = options[:cmd]

      kubectl_on_latest_pod(
        website: website,
        website_location: website_location,
        pod_name: options[:pod_name],
        s_arguments: "exec POD_NAME -- #{cmd}",
        pod_name_delimiter: "POD_NAME"
      )
    end

    def wait_for_service_load_balancer(website, website_location)
      load_balancer = nil

      18.times do |_iteration|
        services = get_services_json(
          website: website,
          website_location: website_location,
          with_namespace: true # for the given custom domain
        )

        load_balancer = find_first_load_balancer(services)

        return load_balancer if load_balancer

        sleep 10 if ENV['RAILS_ENV'] != 'test'
      end

      'unavailable CNAME - unable to get the load balancer address'
    end

    def final_instance_details(opts = {})
      result = {}

      website, website_location = get_website_fields(opts)

      result['result'] = 'success'
      result['url'] = "http://#{website_location.main_domain}/"

      if website.domain_type == 'custom_domain'
        notify('info', 'Custom domain - The DNS documentation is available at ' \
                        'https://www.openode.io/docs/platform/dns.md')

        kconfs_at = Kubernetes.kube_configs_at_location(website_location.location.str_id)

        result['CNAME Record'] = kconfs_at['cname']
      end

      result
    end

    def notify_final_instance_details(opts = {})
      get_website_fields(opts)
      final_details = final_instance_details(opts)

      notify('info', details: final_details)
    end

    def finalize(options = {})
      website, website_location = get_website_fields(options)
      super(options)
      website.reload

      begin
        pods = get_pods_json(
          website: website,
          website_location: website_location
        )

        analyze_final_pods_state(pods)

        unless website.online?
          analyze_deployment_failure(
            website: website,
            website_location: website_location,
            pods: pods
          )
        end

        ex_stdout('logs', website: website,
                          website_location: website_location,
                          pod_name: get_latest_pod_name_in(pods),
                          nb_lines: 1_000)
      rescue StandardError => e
        Ex::Logger.info(e, 'Unable to retrieve the logs')
      end

      begin
        if website.online?
          store_services(website: website, website_location: website_location)
          notify_final_instance_details(options)
        else
          # stop it
          do_stop(options.merge(skip_notify_errors: true))
        end
      rescue StandardError => e
        Ex::Logger.info(e, 'Unable to finalize completely')
      end

      notify('info', "\n\n*** Final Deployment state: #{runner&.execution&.status&.upcase} ***\n")
    end

    def store_services(options = {})
      wl = options.dig(:website_location)

      args = {
        website_location: wl,
        with_namespace: true,
        s_arguments: "get services -o json"
      }

      services = JSON.parse(ex_stdout("kubectl", args))
      wl.obj ||= {}
      wl.obj['services'] = services
      wl.save
    end

    ### Finalization analysis

    # POD analysis

    def analyse_pod_status_for_lack_memory(name, status)
      reason = status.dig('lastState', 'terminated', 'reason')&.downcase

      return unless reason == "oomkilled"

      msg = "\n\n*** FATAL: Lack of memory detected on application #{name}! " \
            "Consider upgrading your plan. ***\n"

      notify('info', msg)

      msg
    end

    def analyze_final_pods_state(pods)
      pods['items'].each do |pod|
        pod.dig('status', 'containerStatuses').each do |st|
          analyse_pod_status_for_lack_memory(st['name'], st)
        end
      end
    rescue StandardError => e
      Ex::Logger.error(e, 'Issue analysing the pods state')
    end

    # PORT analysis
    def analyze_netstat_tcp_ports(opts = {})
      lastest_pod_name = get_latest_pod_name_in(opts[:pods])
      result = ex('custom_cmd',
                  website: opts[:website],
                  website_location: opts[:website_location],
                  cmd: "netstat -tl",
                  pod_name: lastest_pod_name)

      netstats = Io::Netstat.parse(result.dig(:stdout))

      # check the port
      port_available = netstats.any? do |netstat|
        Io::Netstat.addr_port_available?(netstat[:local_addr], %w[80 http HTTP]) &&
          netstat[:state] == 'listen'
      end

      unless port_available
        notify('error', "IMPORTANT: HTTP port (80) NOT listening. " \
                        "Currently listening ports: #{Io::Netstat.local_addr_ports(netstats)}")
      end

      # check hostname
      hostname_all = netstats.any? do |netstat|
        Io::Netstat.addr_port_available?(netstat[:local_addr], %w[80 http HTTP]) &&
          Io::Netstat.addr_host_to_all?(netstat[:local_addr])
      end

      if port_available && !hostname_all
        notify('error', "IMPORTANT: The proper port is listening, BUT not to all hosts" \
                        " (more likely only listening to localhost for example)")
      end

      if !port_available || !hostname_all
        notify('debug', "Netstat: #{netstats.inspect}")
      end
    rescue StandardError => e
      Ex::Logger.error(e, 'Issue analysing the port-host listening')
    end

    # will notifies kube events of all types in the namespace
    def analyze_final_events(opts = {})
      kubectl_args = {
        website_location: opts[:website_location],
        with_namespace: true,
        s_arguments: "get events -o json"
      }
      result = JSON.parse(ex("kubectl", kubectl_args).dig(:stdout))

      result.dig('items').each do |event|
        entity = event.dig('involvedObject', 'kind')
        reason = event.dig('reason')
        message = event.dig('message')
        notify("debug", "Event - entity: #{entity}, reason: #{reason}, message: #{message}")
      end
    rescue StandardError => e
      Ex::Logger.error(e, 'Issue analysing final events')
    end

    def analyze_deployment_failure(opts = {})
      require_fields([:website, :website_location, :pods], opts)

      analyze_final_events(opts)
      analyze_netstat_tcp_ports(opts)
    end

    ### End Finalization analysis

    # the following hooks are notification procs.

    def self.hook_error
      proc do |level, msg|
        msg if level == 'error'
      end
    end

    def self.hook_cmd_is(obj, cmds_name)
      cmds_name.include?(obj.andand[:cmd_name])
    end

    def self.hook_cmd_state_is(obj, cmd_state)
      obj.andand[:cmd_state] == cmd_state
    end

    def self.hook_cmd_and_state(cmds_name, cmd_state, output)
      proc do |_, msg|
        if hook_cmd_is(msg, cmds_name) && hook_cmd_state_is(msg, cmd_state)
          output
        end
      end
    end

    def self.hook_verify_can_deploy
      DockerCompose.hook_cmd_and_state(['verify_can_deploy'], 'before',
                                       'Verifying allowed to deploy...')
    end

    def self.hook_logs
      proc do |_, msg|
        if hook_cmd_is(msg, ['logs']) && hook_cmd_state_is(msg, 'after')
          msg[:result][:stdout]
        end
      end
    end

    def self.hook_verify_instance_up
      Kubernetes.hook_cmd_and_state(%w[verify_instance_up],
                                    'before',
                                    'Verifying instance up...')
    end

    def self.hook_verify_instance_up_done
      Kubernetes.hook_cmd_and_state(['verify_instance_up'],
                                    'after',
                                    '...instance verification finished.')
    end

    def self.hook_finalize
      Kubernetes.hook_cmd_and_state(['finalize'],
                                    'before',
                                    'Finalizing...')
    end

    def self.hook_finalize_done
      Kubernetes.hook_cmd_and_state(['finalize'],
                                    'after',
                                    '...finalized.')
    end

    def hooks
      [
        Kubernetes.hook_error,
        Kubernetes.hook_verify_can_deploy,
        Kubernetes.hook_logs,
        Kubernetes.hook_finalize,
        Kubernetes.hook_finalize_done,
        Kubernetes.hook_verify_instance_up,
        Kubernetes.hook_verify_instance_up_done
      ]
    end

    def kubeconfig_path(location)
      location_str_id = location.str_id
      configs = Kubernetes.kube_configs_at_location(location_str_id)

      raise "missing kubeconfig for #{location_str_id}" unless configs

      path = configs['builder_kubeconfig_path']

      assert path

      path
    end
  end
end
