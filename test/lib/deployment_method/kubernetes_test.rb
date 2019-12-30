
require 'test_helper'

class DeploymentMethodKubernetesTest < ActiveSupport::TestCase
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first
  end

  def kubernetes_method
    runner = prepare_kubernetes_runner(@website, @website_location)

    runner.get_execution_method
  end

  # verify can deploy

  test 'verify_can_deploy - can do it' do
    dep_method = kubernetes_method

    dep_method.verify_can_deploy(website: @website, website_location: @website_location)
  end

  test 'verify_can_deploy - lacking credits' do
    dep_method = kubernetes_method
    user = @website.user
    user.credits = 0
    user.save!

    assert_raises StandardError do
      dep_method.verify_can_deploy(website: @website, website_location: @website_location)
    end
  end

  # initialization

  test 'initialization with crontab' do
    @website.crontab = '* * * * * ls'
    @website.save!
    dep_method = kubernetes_method

    begin_sftp
    dep_method.initialization(website: @website, website_location: @website_location)

    up_files = Remote::Sftp.get_test_uploaded_files

    assert_equal up_files.length, 1

    assert_equal up_files[0][:content], @website.crontab
    assert_equal up_files[0][:remote_file_path], "#{@website.repo_dir}.openode.cron"
  end

  test 'initialization without crontab' do
    @website.crontab = nil
    @website.save!
    dep_method = kubernetes_method

    begin_sftp
    dep_method.initialization(website: @website, website_location: @website_location)

    up_files = Remote::Sftp.get_test_uploaded_files

    assert_equal up_files.length, 0
  end

  test 'retrieve_dotenv_cmd' do
    generated_cmd = kubernetes_method.retrieve_dotenv_cmd(project_path: '/home/what/')
    assert_equal generated_cmd, "cat /home/what/.env"
  end

  test 'retrieve_dotenv without dotenv' do
    generated_cmd = kubernetes_method.retrieve_dotenv_cmd(project_path: @website.repo_dir)

    prepare_ssh_session(generated_cmd, '')

    assert_scripted do
      begin_ssh
      dotenv_content = kubernetes_method.retrieve_dotenv(@website)

      assert_equal dotenv_content, {}
    end
  end

  test 'retrieve_dotenv with dotenv' do
    generated_cmd = kubernetes_method.retrieve_dotenv_cmd(project_path: @website.repo_dir)

    dotenv_content = '

VAR1=1234
VAR2=5678
    '
    prepare_ssh_session(generated_cmd, dotenv_content)

    assert_scripted do
      begin_ssh
      dotenv_result = kubernetes_method.retrieve_dotenv(@website)

      assert_equal dotenv_result["VAR1"], "1234"
      assert_equal dotenv_result["VAR2"], "5678"
    end
  end

  test 'namespace_of website' do
    assert_equal kubernetes_method.namespace_of(@website), "instance-#{@website.id}"
  end

  def assert_contains_namespace_yml(yml, website)
    assert_includes yml, "kind: Namespace"
    assert_includes yml, "  name: #{kubernetes_method.namespace_of(website)}"
  end

  test 'generate_namespace_yml' do
    yml = kubernetes_method.generate_namespace_yml(@website)
    assert_contains_namespace_yml(yml, @website)
  end

  def assert_contains_deployment_yml(yml, website, opts = {})
    assert_includes yml, "kind: Deployment"
    assert_includes yml, "  name: www-deployment"
    assert_includes yml, "  namespace: #{kubernetes_method.namespace_of(website)}"
    assert_includes yml, "  replicas: 1"
    assert_includes yml, "  livenessProbe:" if opts[:with_probes]
    assert_includes yml, "  readinessProbe:" if opts[:with_probes]
    assert_includes yml, "  resources:"

    # docker registry secret
    assert_includes yml, "imagePullSecrets:"
    assert_includes yml, "- name: regcred"

    # Memory limitation
    assert_includes yml, "memory: #{opts[:requested_memory]}Mi" if opts[:requested_memory]
    assert_includes yml, "memory: #{opts[:limited_memory]}Mi" if opts[:limited_memory]

    # CPU limitation
    assert_includes yml, "cpu: #{opts[:requested_cpus]}" if opts[:requested_cpus]
    assert_includes yml, "cpu: #{opts[:limited_cpus]}" if opts[:limited_cpus]
  end

  test 'generate_deployment_yml - basic' do
    yml = kubernetes_method.generate_deployment_yml(@website, @website_location)

    assert_contains_deployment_yml(yml, @website,
                                   requested_memory: @website.memory,
                                   limited_memory: @website.memory * 2,
                                   requested_cpus: @website.cpus,
                                   limited_cpus: @website.cpus * 2,
                                   with_probes: true)
  end

  test 'generate_deployment_yml - with skip port check' do
    @website.configs = {
      "SKIP_PORT_CHECK": "true"
    }
    @website.save!
    yml = kubernetes_method.generate_deployment_yml(@website, @website_location)

    assert_contains_deployment_yml(yml, @website,
                                   requested_memory: @website.memory,
                                   limited_memory: @website.memory * 2,
                                   requested_cpus: @website.cpus,
                                   limited_cpus: @website.cpus * 2,
                                   with_probes: false)
  end

  test 'generate_deployment_probes_yml - with probes' do
    yml = kubernetes_method.generate_deployment_probes_yml(@website)

    assert_includes yml, "livenessProbe:"
    assert_includes yml, "readinessProbe:"
  end

  test 'generate_deployment_probes_yml - without probes' do
    @website.configs = {
      "SKIP_PORT_CHECK": "true"
    }
    @website.save!

    yml = kubernetes_method.generate_deployment_probes_yml(@website)

    assert_not_includes yml, "livenessProbe:"
    assert_not_includes yml, "readinessProbe:"
  end

  def assert_contains_service_yml(yml, website)
    assert_includes yml, "kind: Service"
    assert_includes yml, "name: main-service"
    assert_includes yml, "namespace: #{kubernetes_method.namespace_of(website)}"
    assert_includes yml, "app: www"
  end

  test 'generate_service_yml - basic' do
    yml = kubernetes_method.generate_service_yml(@website)
    assert_contains_service_yml(yml, @website)
  end

  def assert_contains_ingress_yml(yml, website, website_location)
    domains = website_location.compute_domains

    assert_includes yml, "kind: Ingress"
    assert_includes yml, "name: main-ingress"
    assert_includes yml, "namespace: #{kubernetes_method.namespace_of(website)}"
    assert_includes yml, "ingress.class: \"nginx\""

    domains.each do |domain|
      assert_includes yml, "- host: #{domain}"
    end
  end

  test 'generate_ingress_yml' do
    yml = kubernetes_method.generate_ingress_yml(@website, @website_location)
    assert_contains_ingress_yml(yml, @website, @website_location)
  end

  test 'generate_instance_yml - basic' do
    cmd_get_dotenv = kubernetes_method.retrieve_dotenv_cmd(project_path: @website.repo_dir)
    prepare_ssh_session(cmd_get_dotenv, '')

    assert_scripted do
      begin_ssh

      yml = kubernetes_method.generate_instance_yml(@website, @website_location)

      assert_contains_namespace_yml(yml, @website)
      assert_contains_deployment_yml(yml, @website, with_probes: true)
      assert_contains_service_yml(yml, @website)
      assert_contains_ingress_yml(yml, @website, @website_location)
    end
  end

  test 'cmd_docker_registry_secret' do
    cloud_provider_manager = CloudProvider::Manager.instance
    cmd = kubernetes_method.cmd_docker_registry_secret(
      @website, cloud_provider_manager.docker_images_location
    )

    assert_includes cmd, "-n instance-#{@website.id} create secret docker-registry regcred"
    assert_includes cmd, "--docker-server=https://index.docker.io/v1/"
    assert_includes cmd, "--docker-username=test"
    assert_includes cmd, "--docker-email=test@openode.io"
  end
end
