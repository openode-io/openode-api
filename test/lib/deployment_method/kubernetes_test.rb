
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

  def assert_contains_minimal_deployment_yml(yml, website)
    assert_includes yml, "kind: Deployment"
    assert_includes yml, "  name: www-deployment"
    assert_includes yml, "  namespace: #{kubernetes_method.namespace_of(website)}"
    assert_includes yml, "  replicas: 1"
    assert_includes yml, "  livenessProbe:"
    assert_includes yml, "  readinessProbe:"
    assert_includes yml, "  resources:"

    # docker registry secret
    assert_includes yml, "imagePullSecrets:"
    assert_includes yml, "- name: regcred"
  end

  test 'generate_deployment_yml - basic' do
    yml = kubernetes_method.generate_deployment_yml(@website, @website_location)
    assert_contains_minimal_deployment_yml(yml, @website)
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

  test 'generate_instance_yml' do
    yml = kubernetes_method.generate_instance_yml(@website, @website_location)

    assert_contains_namespace_yml(yml, @website)
    assert_contains_minimal_deployment_yml(yml, @website)
    assert_contains_service_yml(yml, @website)
    assert_contains_ingress_yml(yml, @website, @website_location)
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
