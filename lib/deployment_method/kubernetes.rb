require 'dotenv'

module DeploymentMethod
  class Kubernetes < Base
    KUBECONFIGS_BASE_PATH = "config/kubernetes/"

    def initialize; end

    # verify can deploy

    def verify_can_deploy(options = {})
      super(options)
    end

    def initialization(options = {})
      super(options)

      send_crontab(options)
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

    def launch(options = {})
      website, website_location = get_website_fields(options)

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

      notify("info", "Preparing instance image...")
      image_manager.verify_size_repo
      image_manager.build
      notify("info", "Instance image ready.")

      # then push it to the registry
      notify("info", "Pushing instance image...")
      image_manager.push
      notify("info", "Instance image pushed successfully.")

      # generate the yml to the build machine
      kube_yml = generate_instance_yml(website, website_location,
                                       image_name_tag: image_manager.image_name_tag)

      notify("info", "Applying instance environment...")

      # then apply the yml
      result = kubectl_yml_action(website_location, "apply", kube_yml, ensure_exit_code: 0)

      notify("info", result[:stdout])

      result
    end

    def kubectl(options = {})
      assert options[:website_location]
      assert options[:s_arguments]
      website = options[:website_location].website

      config_path = kubeconfig_path(options[:website_location])

      namespace = options[:with_namespace] ? "-n #{namespace_of(website)}" : ""

      cmd = "KUBECONFIG=#{config_path} kubectl #{namespace} #{options[:s_arguments]}"

      cmd
    end

    def kubectl_yml_action(website_location, action, content, opts = {})
      tmp_file = Tempfile.new("kubectl-#{action}")

      tmp_file.write(content)
      tmp_file.flush

      ex('kubectl', {
        website_location: website_location,
        s_arguments: "#{action} -f #{tmp_file.path}"
      }.merge(opts))
    end

    def retrieve_dotenv_cmd(options = {})
      project_path = options[:project_path]

      "cat #{project_path}.env"
    end

    def retrieve_dotenv(website)
      dotenv_content = ex_stdout("retrieve_dotenv_cmd", project_path: website.repo_dir)

      Dotenv::Parser.call(dotenv_content || '')
    end

    def generate_instance_yml(website, website_location, opts = {})
      retrieve_dotenv(website)

      <<~END_YML
        ---
        #{generate_namespace_yml(website)}
        ---
        #{generate_deployment_yml(website, opts)}
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

    def generate_deployment_yml(website, opts)
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
              containers:
              - image: #{opts[:image_name_tag]}
                imagePullPolicy: Always
                name: www
                envFrom:
                #- configMapRef:
                #    name: test-config-map
                ports:
                - containerPort: 80
        #{generate_deployment_probes_yml(website)}
                resources:
                  limits: # more resources if available in the cluster
                    ephemeral-storage: 100Mi
                    memory: #{website.memory * 2}Mi
                    cpu: #{website.cpus * 2}
                  requests:
                    ephemeral-storage: 100Mi
                    memory: #{website.memory}Mi
                    cpu: #{website.cpus}
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
          ports:
          - port: 80
            targetPort: 80
            protocol: TCP
          selector:
            app: www
      END_YML
    end

    def generate_rules_ingress_yml(rules = [])
      result = ""

      rules.each do |rule|
        result +=
          <<~END_YML
            - host: #{rule[:hostname]}
                http:
                  paths:
                  - path: /
                    backend:
                      serviceName: main-service
                      servicePort: 80
          END_YML
      end

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
            # cert-manager.io/cluster-issuer: "letsencrypt-prod"
        spec:
          #tls:
          #- hosts:
          #  - myprettyprettytest112233.openode.io
          #  secretName: quickstart-example-tls23
          rules:
          #{generate_rules_ingress_yml(rules_domains)}
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
      DockerCompose.hook_cmd_and_state(%w[verify_instance_up],
                                       'before',
                                       'Verifying instance up...')
    end

    def self.hook_verify_instance_up_done
      DockerCompose.hook_cmd_and_state(['verify_instance_up'],
                                       'after',
                                       '...instance verification finished.')
    end

    def self.hook_finalize
      DockerCompose.hook_cmd_and_state(['finalize'],
                                       'before',
                                       'Finalizing...')
    end

    def self.hook_finalize_done
      DockerCompose.hook_cmd_and_state(['finalize'],
                                       'after',
                                       '...finalized.')
    end

    def hooks
      [
        DockerCompose.hook_error,
        DockerCompose.hook_verify_can_deploy,
        DockerCompose.hook_logs,
        DockerCompose.hook_finalize,
        DockerCompose.hook_finalize_done,
        DockerCompose.hook_verify_instance_up,
        DockerCompose.hook_verify_instance_up_done
      ]
    end

    protected

    def kubeconfig_path(website_location)
      location_str_id = website_location.location.str_id
      Rails.root.join("#{KUBECONFIGS_BASE_PATH}#{ENV['RAILS_ENV']}-#{location_str_id}.yml")
    end
  end
end
