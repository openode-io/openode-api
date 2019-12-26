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

      puts "before kube path.."

      puts "kube path "

      # generate the deployment yml

      # write the yml to the build machine

      # apply
      result = kubectl_yml_action(website_location, "apply", generate_deployment_yml(website))

      result
    end

    def kubectl(options = {})
      assert options[:website_location]
      assert options[:s_arguments]

      config_path = kubeconfig_path(options[:website_location])
      cmd = "KUBECONFIG=#{config_path} kubectl #{options[:s_arguments]}"

      puts "cmd -> #{cmd}"
      cmd
    end

    def kubectl_yml_action(website_location, action, content)
      tmp_file = Tempfile.new("kubectl-apply")

      tmp_file.write(content)
      tmp_file.flush

      content = File.read(tmp_file.path)

      puts "my content"
      puts content

      ex_stdout('kubectl',
                website_location: website_location,
                s_arguments: "#{action} -f #{tmp_file.path}")
    end

    def generate_deployment_yml(website)
      <<~END_YML
        ---
        apiVersion: v1
        kind: Namespace
        metadata:
          name: instance-#{website.id}
        ---
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
