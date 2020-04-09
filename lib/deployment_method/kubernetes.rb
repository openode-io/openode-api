require 'dotenv'
require 'base64'

module DeploymentMethod
  class Kubernetes < Base
    KUBECONFIGS_BASE_PATH = "config/kubernetes/"
    CERTS_BASE_PATH = "config/certs/"

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

    def launch(options = {})
      website, website_location = get_website_fields(options)

      initialize_ns(options)
      image_manager = prepare_image_manager(website, website_location)

      notify("info", "Preparing instance image...")
      image_manager.verify_size_repo
      result_build = image_manager.build
      notify("info", result_build.first&.dig(:result, :stdout)) if result_build&.first
      notify("info", "Instance image ready.")

      # then push it to the registry
      notify("info", "Pushing instance image...")
      image_manager.push
      notify("info", "Instance image pushed successfully.")

      # generate the yml to the build machine
      kube_yml = generate_instance_yml(website, website_location,
                                       with_namespace_object: true,
                                       with_pvc_object: true,
                                       image_name_tag: image_manager.image_name_tag)

      notify("info", "Applying instance environment...")

      if website.subdomain? && website.type == Website::TYPE_KUBERNETES
        notify("info",
               "Important notice: subdomains have <your sitename>.dev.openode.io " \
               "without SSL during the beta phase. Soon they will be replaced with " \
               "<your sitename>.openode.io and with HTTPS.")
      end

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
                         ensure_exit_code: 0,
                         skip_notify_errors: options[:skip_notify_errors])
    end

    def reload(options = {})
      launch(options)
    end

    def kubectl(options = {})
      assert options[:website_location]
      assert options[:s_arguments]
      website = options[:website_location].website

      config_path = kubeconfig_path(options[:website_location])

      namespace = options[:with_namespace] ? "-n #{namespace_of(website)} " : ""

      cmd = "KUBECONFIG=#{config_path} kubectl #{namespace}#{options[:s_arguments]}"
      cmd
    end

    @@test_kubectl_file_path = nil

    def self.set_kubectl_file_path(kube_file_path)
      @@test_kubectl_file_path = kube_file_path
    end

    def self.yml_remote_file_path(action)
      if !@@test_kubectl_file_path
        tmp_file = Tempfile.new("kubectl-#{action}")

        tmp_file.path
      else
        @@test_kubectl_file_path
      end
    end

    def kubectl_yml_action(website_location, action, content, opts = {})
      # upload(local_path, remote_path)
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

    def retrieve_dotenv(website)
      dotenv_content = ex_stdout("retrieve_dotenv_cmd", website: website)

      Dotenv::Parser.call(dotenv_content || '')
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

      # TODO: REMOVE && type kubernetes when beta finished

      <<~END_YML
        ---
        #{generate_namespace_yml(website) if opts[:with_namespace_object]}
        ---
        #{generate_persistence_volume_claim_yml(website_location) if opts[:with_pvc_object]}
        ---
        #{generate_manual_tls_secret_yml(website)}
        ---
        #{generate_wildcard_subdomain_tls_secret_yaml(website) if website.subdomain? && website.type != Website::TYPE_KUBERNETES}
        ---
        #{generate_config_map_yml(
          name: 'dotenv',
          namespace: namespace_of(website),
          variables: dotenv_vars
        )}
        ---
        #{generate_deployment_yml(website, website_location, opts)}
        ---
        #{generate_service_yml(website)}
        ---
        #{generate_ingress_yml(website, website_location)}
        ---
      END_YML
    end

    def namespace_of(website)
      "instance-#{website.id}"
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

    def generate_deployment_probes_yml(website)
      return '' if website.skip_port_check?

      '
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 120
          periodSeconds: 600
          timeoutSeconds: 3
          failureThreshold: 1
        readinessProbe:
          httpGet:
            path: /
            port: 80
          periodSeconds: 10
          initialDelaySeconds: 5
      '
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

    def generate_deployment_yml(website, website_location, opts)
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
          replicas: 1
          template:
            metadata:
              labels:
                app: www
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
        #{generate_deployment_probes_yml(website)}
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
      # TODO: remove && website.type when beta finished
      website.certs.present? || (website.subdomain? && website.type != Website::TYPE_KUBERNETES)
    end

    def certificate_secret_name(website)
      if website.certs.present?
        "manual-certificate"
      elsif website.subdomain? && website.type != Website::TYPE_KUBERNETES
        # TODO: remove && when beta finished
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

      crt = ex("retrieve_file_cmd",
               ensure_exit_code: 0,
               path: "#{website.repo_dir}#{website.certs[:cert_path]}")[:stdout]
      crt_key = ex("retrieve_file_cmd",
                   ensure_exit_code: 0,
                   path: "#{website.repo_dir}#{website.certs[:cert_key_path]}")[:stdout]

      generate_tls_secret_yml(website,
                              name: certificate_secret_name(website),
                              crt: crt,
                              key: crt_key)
    end

    def generate_wildcard_subdomain_tls_secret_yaml(website)
      wildcard_crt_path =
        Rails.root.join("#{CERTS_BASE_PATH}#{ENV['RAILS_ENV']}-wildcard.crt")
      wildcard_key_path =
        Rails.root.join("#{CERTS_BASE_PATH}#{ENV['RAILS_ENV']}-wildcard.key")

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

      rules << rules[0]

      rules.each do |rule|
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

      kubectl_on_latest_pod(
        website: website,
        website_location: website_location,
        pod_name: options[:pod_name],
        s_arguments: "logs POD_NAME --tail=#{options[:nb_lines]}",
        pod_name_delimiter: "POD_NAME"
      )
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
        default_services = get_services_json(
          website: website,
          website_location: website_location,
          with_namespace: false
        )

        load_balancer = find_first_load_balancer!(default_services)

        kconfs_at = Kubernetes.kube_configs_at_location(website_location.location.str_id)

        result['A Record'] = load_balancer
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
        ex_stdout('logs', website: website,
                          website_location: website_location,
                          nb_lines: 1_000)
      rescue StandardError => e
        Ex::Logger.info(e, 'Unable to retrieve the logs')
      end

      begin
        if website.online?
          notify_final_instance_details(options)
        else
          # stop it
          do_stop(options.merge(skip_notify_errors: true))
        end
      rescue StandardError => e
        Ex::Logger.info(e, 'Unable to finalize completely')
      end

      notify('info', "\n\n*** Final Deployment state: #{runner&.execution&.status} ***\n")
    end

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

    def kubeconfig_path(website_location)
      location_str_id = website_location.location.str_id
      configs = Kubernetes.kube_configs_at_location(location_str_id)

      raise "missing kubeconfig for #{location_str_id}" unless configs

      path = configs['builder_kubeconfig_path']

      assert path

      path
    end
  end
end
