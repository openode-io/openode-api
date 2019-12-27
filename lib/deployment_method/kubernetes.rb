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

    def launch(options = {})
      website, website_location = get_website_fields(options)

      # generate the deployment yml

      # write the yml to the build machine

      # apply
      result = kubectl_yml_action(website_location, "apply", generate_instance_yml(website))

      result
    end

    def kubectl(options = {})
      assert options[:website_location]
      assert options[:s_arguments]

      config_path = kubeconfig_path(options[:website_location])
      cmd = "KUBECONFIG=#{config_path} kubectl #{options[:s_arguments]}"

      cmd
    end

    def kubectl_yml_action(website_location, action, content)
      tmp_file = Tempfile.new("kubectl-apply")

      tmp_file.write(content)
      tmp_file.flush

      ex_stdout('kubectl',
                website_location: website_location,
                s_arguments: "#{action} -f #{tmp_file.path}")
    end

    def generate_instance_yml(website)
      <<~END_YML
        ---
        #{generate_namespace_yml(website)}
        ---
        #{generate_deployment_yml(website)}
        ---
        #{generate_service_yml(website)}
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

    def generate_deployment_yml(website)
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
              containers:
              - image: nginx # gcr.io/kuar-demo/kuard-amd64:1
                imagePullPolicy: Always
                name: www
                envFrom:
                #- configMapRef:
                #    name: test-config-map
                ports:
                - containerPort: 80
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
                resources:
                  limits:
                    ephemeral-storage: 100Mi
                    memory: 100Mi
                    cpu: 1
                  requests:
                    ephemeral-storage: 100Mi
                    memory: 50Mi
                    cpu: 0.5
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

    def hooks
      [
        DockerCompose.hook_error,
        DockerCompose.hook_verify_can_deploy,
        DockerCompose.hook_logs
      ]
    end

    protected

    def kubeconfig_path(website_location)
      location_str_id = website_location.location.str_id
      Rails.root.join("#{KUBECONFIGS_BASE_PATH}#{ENV['RAILS_ENV']}-#{location_str_id}.yml")
    end
  end
end
