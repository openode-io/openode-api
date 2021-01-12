
require 'base64'
require 'test_helper'
require 'test_kubernetes_helper'

class DeploymentMethodKubernetesTest < ActiveSupport::TestCase
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first
  end

  def kubernetes_method
    @runner ||= prepare_kubernetes_runner(@website, @website_location)

    @runner.get_execution_method
  end

  def prepare_get_pods_happy(_website_location)
    cmd = kubernetes_method.kubectl(
      website_location: @website_location,
      with_namespace: true,
      s_arguments: "get pods -o json"
    )

    prepare_ssh_session(cmd, IO.read('test/fixtures/kubernetes/1_pod_alive.json'))
  end

  # kubeconfig path
  test 'kubeconfig_path' do
    dep_method = kubernetes_method
    location = Location.find_by str_id: 'usa'

    path = dep_method.kubeconfig_path(location)

    assert_equal path, '/var/www/openode-api/config/kubernetes/production-usa.yml'
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

  test 'verify_can_deploy - using subscription' do
    dep_method = kubernetes_method
    SubscriptionWebsite.destroy_all
    user = @website.user
    user.credits = 0
    user.save!

    @website.account_type = Website::AUTO_ACCOUNT_TYPE
    @website.save!

    Subscription.create!(user: user, quantity: 2, active: true)

    dep_method.verify_can_deploy(website: @website, website_location: @website_location)
  end

  test 'delete files generate proper command' do
    result = kubernetes_method.delete_files(files: ['/home/4/test.txt', '/home/what/isthat'])
    assert_equal result, 'rm -rf "/home/4/test.txt" ; rm -rf "/home/what/isthat" ; '
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

  # kube_configs
  test 'kube_configs' do
    configs = DeploymentMethod::Kubernetes.kube_configs
    assert_equal configs['storage_class_name'], 'do-block-storage'
  end

  # kube_configs_at_location
  test 'kube_configs_at_location' do
    confs = DeploymentMethod::Kubernetes.kube_configs_at_location('canada')
    assert_equal confs['cname'], 'canada.openode.io'
    assert_equal confs['external_addr'], '127.0.0.1'
  end

  # DOTENV

  test 'retrieve_dotenv_cmd' do
    w = default_website
    generated_cmd = kubernetes_method.retrieve_dotenv_cmd(website: w)
    assert_equal generated_cmd, "cat #{w.repo_dir}.env"
  end

  test 'retrieve_dotenv_cmd with custom dotenv filepath' do
    w = default_website
    w.configs ||= {}
    w.configs['DOTENV_FILEPATH'] = '.production.env'
    w.save!
    generated_cmd = kubernetes_method.retrieve_dotenv_cmd(website: w)
    assert_equal generated_cmd, "cat #{w.repo_dir}.production.env"
  end

  test 'retrieve_dotenv without dotenv' do
    generated_cmd = kubernetes_method.retrieve_dotenv_cmd(website: @website)

    prepare_ssh_session(generated_cmd, '')

    assert_scripted do
      begin_ssh
      dotenv_content = kubernetes_method.retrieve_dotenv(@website)

      assert_equal dotenv_content, {}
    end
  end

  test 'retrieve_dotenv with dotenv' do
    generated_cmd = kubernetes_method.retrieve_dotenv_cmd(website: @website)

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

  test 'retrieve_dotenv with dotenv and stored env' do
    @website.store_env_variable!("VAR2", "56789")
    @website.store_env_variable!("VAR3", "HIWORLD")
    generated_cmd = kubernetes_method.retrieve_dotenv_cmd(website: @website)

    dotenv_content = '

VAR1=1234
VAR2=5678
    '
    prepare_ssh_session(generated_cmd, dotenv_content)

    assert_scripted do
      begin_ssh
      dotenv_result = kubernetes_method.retrieve_dotenv(@website)

      assert_equal dotenv_result["VAR1"], "1234"
      assert_equal dotenv_result["VAR2"], "56789"
      assert_equal dotenv_result["VAR3"], "HIWORLD"
    end
  end

  test 'dotenv_vars_to_s without variable' do
    assert_equal kubernetes_method.dotenv_vars_to_s({}), ""
  end

  test 'dotenv_vars_to_s with variables' do
    vars = {
      'var1': 'val1',
      'var12': 'val\\12',
      'var2': 2,
      'va_r3': 'va"l'
    }

    expected = "  var1: \"val1\"\n" \
    "  var12: \"val\\\\12\"\n" \
    "  var2: \"2\"\n" \
    "  va_r3: \"va\\\"l\""

    result = kubernetes_method.dotenv_vars_to_s(vars)

    assert_equal result, expected
  end

  # retrieve_remote_file
  test 'retrieve_remote_file - without parent execution' do
    prepare_ssh_session("cat #{@website.repo_dir}.env", "TEST=123")

    assert_scripted do
      begin_ssh

      result = kubernetes_method.retrieve_remote_file(
        name: 'dotenv',
        cmd: 'retrieve_dotenv_cmd',
        website: @website
      )

      assert_equal result, "TEST=123"
    end
  end

  test 'retrieve_remote_file - with parent execution' do
    parent_execution = Deployment.create!(
      website: @website,
      website_location: @website_location,
      status: Deployment::STATUS_RUNNING
    )

    assert_scripted do
      begin_ssh

      kubernetes_method.runner.init_execution!('Deployment',
                                               'parent_execution_id' => parent_execution.id)

      execution = kubernetes_method.runner.execution

      execution.parent_execution = parent_execution
      execution.save

      # add dotenv in the vault
      execution.parent_execution.save_secret!(dotenv: 'TITI=toto')

      result = kubernetes_method.retrieve_remote_file(
        name: 'dotenv',
        cmd: 'retrieve_dotenv_cmd',
        website: @website
      )

      assert_equal result, "TITI=toto"
    end
  end

  test 'retrieve_remote_file - with reference_website_image' do
    referenced_website = Website.last

    img_name_tag = 'mypretty/image'

    original_deployment = Deployment.create!(
      website: referenced_website,
      website_location: @website_location,
      status: Deployment::STATUS_RUNNING,
      obj: {
        image_name_tag: img_name_tag
      }
    )

    set_reference_image_website(@website, referenced_website)

    assert_scripted do
      begin_ssh

      kubernetes_method.runner.init_execution!('Deployment')

      # add dotenv in the vault
      original_deployment.save_secret!(dotenv: 'TITI=toto')

      result = kubernetes_method.retrieve_remote_file(
        name: 'dotenv',
        cmd: 'retrieve_dotenv_cmd',
        website: @website
      )

      assert_equal result, "TITI=toto"
    end
  end

  test 'get_pods_json - happy path' do
    prepare_get_pods_happy(@website_location)

    assert_scripted do
      begin_ssh

      result = kubernetes_method.get_pods_json(
        website: @website,
        website_location: @website_location
      )

      assert_equal result['items'][0]['kind'], 'Pod'
    end
  end

  test 'get_services_json - happy path' do
    prepare_get_services_default_happy(kubernetes_method, @website_location)

    assert_scripted do
      begin_ssh

      result = kubernetes_method.get_services_json(
        website: @website,
        website_location: @website_location,
        with_namespace: false
      )

      assert_equal result['items'][0]['kind'], 'Service'
    end
  end

  test 'find_first_load_balancer default' do
    prepare_get_services_default_happy(kubernetes_method, @website_location)

    assert_scripted do
      begin_ssh

      result = kubernetes_method.get_services_json(
        website: @website,
        website_location: @website_location,
        with_namespace: false
      )

      load_balancer = kubernetes_method.find_first_load_balancer(result)

      assert_equal load_balancer, "6ojq5t5np0.lb.c1.bhs5.k8s.ovh.net"
    end
  end

  test 'find_first_load_balancer in namespace' do
    result = JSON.parse(
      IO.read("test/fixtures/kubernetes/services-with-resolved-load-balancer.json")
    )

    load_balancer = kubernetes_method.find_first_load_balancer!(result)

    assert_equal load_balancer, "6ojq59kjlk.lb.c1.bhs5.k8s.ovh.net"
  end

  test 'find_first_load_balancer in namespace - not yet resolved' do
    result = JSON.parse(
      IO.read("test/fixtures/kubernetes/services-with-pending-load-balancer.json")
    )

    load_balancer = kubernetes_method.find_first_load_balancer(result)

    assert_nil load_balancer
  end

  test 'find_first_load_balancer! in namespace - not yet resolved' do
    result = JSON.parse(
      IO.read("test/fixtures/kubernetes/services-with-pending-load-balancer.json")
    )

    assert_raises StandardError do
      kubernetes_method.find_first_load_balancer!(result)
    end
  end

  test 'get_latest_pod_in - happy path' do
    obj = JSON.parse(IO.read('test/fixtures/kubernetes/2_pods_1_successfully_deploying.json'))

    result = kubernetes_method.get_latest_pod_in(obj)

    assert_equal result['metadata']['name'], 'www-deployment-84dcfdfdf6-w4lv9'
  end

  test 'get_latest_pod_name_in - happy path' do
    obj = JSON.parse(IO.read('test/fixtures/kubernetes/2_pods_1_successfully_deploying.json'))

    result = kubernetes_method.get_latest_pod_name_in(obj)

    assert_equal result, 'www-deployment-84dcfdfdf6-w4lv9'
  end

  test 'get_latest_pod_in - no items' do
    result = kubernetes_method.get_latest_pod_in('what': '123')

    assert_equal result, nil
  end

  test 'logs - happy path' do
    result = kubernetes_method.logs(
      website: @website,
      website_location: @website_location
    )

    assert_includes result, "kubectl -n instance-#{@website.id} logs -l app=www --tail=100"
  end

  test 'logs - fail with invalid app name' do
    assert_raise ApplicationRecord::ValidationError do
      kubernetes_method.logs(
        website: @website,
        website_location: @website_location,
        app: 'invalid'
      )
    end
  end

  test 'logs - with addon application' do
    website_addon = WebsiteAddon.create!(
      website: @website,
      addon: Addon.last,
      name: 'hello-redis',
      account_type: 'second'
    )

    result = kubernetes_method.logs(
      website: @website,
      website_location: @website_location,
      app: website_addon.name
    )

    assert_includes result, "kubectl -n instance-#{@website.id} " \
      "logs -l app=#{website_addon.name} --tail=100"
  end

  test 'exec - happy path' do
    # prepare_get_pods_happy(@website_location)

    get_pods_json_content = IO.read('test/fixtures/kubernetes/1_pod_alive.json')
    prepare_get_pods_json(kubernetes_method, @website, @website_location, get_pods_json_content,
                          0, "get pod -l app=www")

    assert_scripted do
      begin_ssh

      result = kubernetes_method.custom_cmd(
        website: @website,
        website_location: @website_location,
        cmd: "ls -la"
      )

      pod_name = "www-deployment-5889df69dc-xg9xl"
      assert_includes result, "kubectl -n instance-#{@website.id} exec #{pod_name} -- ls -la"
    end
  end

  test 'generate_config_map_yml - typical' do
    yml = kubernetes_method.generate_config_map_yml(
      name: "dotenv",
      namespace: "instance-12345",
      variables: {
        'var1': 'v1',
        'var2': 'v2'
      }
    )

    assert_includes yml, "name: dotenv"
    assert_includes yml, "namespace: instance-12345"
    assert_includes yml, "  var1: \"v1\""
    assert_includes yml, "  var2: \"v2\""

    assert Io::Yaml.valid?(yml)
  end

  test 'generate_config_map_yml - with special characters' do
    yml = kubernetes_method.generate_config_map_yml(
      name: "dotenv",
      namespace: "instance-12345",
      variables: {
        'var1': 'v"1',
        'var2': 'v\\2',
        'var3': 'v&2',
        'var4': 'v?2',
        'var5': 'v\'2',
        'var6': 'v=2'
      }
    )

    assert_includes yml, "name: dotenv"
    assert_includes yml, "namespace: instance-12345"
    assert_includes yml, "  var1: \"v\\\"1\""
    assert_includes yml, "  var2: \"v\\\\2\""
    assert_includes yml, "  var3: \"v&2\""
    assert_includes yml, "  var4: \"v?2\""
    assert_includes yml, "  var5: \"v\'2\""
    assert_includes yml, "  var6: \"v=2\""

    assert Io::Yaml.valid?(yml)
  end

  test 'namespace_of website' do
    assert_equal kubernetes_method.namespace_of(@website), "instance-#{@website.id}"
  end

  test 'website_from_namespace with valid website' do
    w = default_website

    found_website = kubernetes_method.website_from_namespace("instance-#{w.id}")

    assert_equal w, found_website
  end

  test 'website_from_namespace with not found website' do
    found_website = kubernetes_method.website_from_namespace("instance-123456")

    assert_nil found_website
  end

  test 'website_from_namespace with invalid namespace' do
    found_website = kubernetes_method.website_from_namespace("instance123")

    assert_nil found_website
  end

  def assert_contains_namespace_yml(yml, website)
    assert_includes yml, "kind: Namespace"
    assert_includes yml, "  name: #{kubernetes_method.namespace_of(website)}"
  end

  test 'generate_namespace_yml' do
    yml = kubernetes_method.generate_namespace_yml(@website)
    assert_contains_namespace_yml(yml, @website)
  end

  def assert_contains_deployment_yml(yml, website, _website_location, opts = {})
    assert_includes yml, "kind: Deployment"
    assert_includes yml, "  name: www-deployment"
    assert_includes yml, "  namespace: #{kubernetes_method.namespace_of(website)}"
    assert_includes yml, "  replicas: #{opts[:replicas] || 1}"
    # assert_includes yml, "  livenessProbe:" if opts[:with_probes]
    assert_includes yml, "  readinessProbe:" if opts[:with_probes]
    assert_includes yml, "  resources:"
    assert_includes yml, "deploymentId: \"#{kubernetes_method.deployment_id}\""

    # docker registry secret
    assert_includes yml, "imagePullSecrets:"
    assert_includes yml, "- name: regcred"

    # Memory limitation
    assert_includes yml, "memory: #{opts[:requested_memory]}Mi" if opts[:requested_memory]
    assert_includes yml, "memory: #{opts[:limited_memory]}Mi" if opts[:limited_memory]

    # Deployment strategy
    assert_includes yml, "type: Recreate" if website.memory <= 1000
    assert_includes yml, "type: Recreate" if website.memory > 1000

    # dotenv
    assert_includes yml, "envFrom:"
    assert_includes yml, "- configMapRef:"
    assert_includes yml, "    name: dotenv"

    persistence_strings_to_expect = [
      "volumes:",
      "- name: main-volume",
      "- mountPath:",
      "volumeMounts:"
    ]

    if opts[:with_persistence]
      persistence_strings_to_expect.each do |s|
        assert_includes yml, s
      end
    else
      persistence_strings_to_expect.each do |s|
        assert_not_includes yml, s
      end
    end
  end

  # deployment strategy
  test 'deployment_strategy - with Recreate and small instance' do
    assert @website.memory <= 1000
    strategy = kubernetes_method.deployment_strategy(@website, @website.memory)

    assert_equal strategy, "Recreate"
  end

  test 'deployment_strategy - with blue green deployment' do
    @website.configs ||= {}
    @website.configs['BLUE_GREEN_DEPLOYMENT'] = true
    @website.save!

    strategy = kubernetes_method.deployment_strategy(@website, @website.memory)

    assert_equal strategy, "RollingUpdate"
  end

  test 'deployment_strategy - with Recreate' do
    @website.account_type = "sixth"
    @website.save!
    assert @website.memory > 1000
    strategy = kubernetes_method.deployment_strategy(@website, @website.memory)

    assert_equal strategy, "Recreate"
  end

  test 'tabulate - 0 tabs' do
    str = "asdf\n" \
          "\n" \
          "  - what"

    assert_equal kubernetes_method.tabulate(0, str), str
  end

  test 'tabulate - 2 tabs' do
    str = "asdf\n" \
          "\n" \
          "  - what"
    expected_str = "    asdf\n" \
                   "    \n" \
                   "      - what"

    assert_equal kubernetes_method.tabulate(2, str), expected_str
  end

  test 'generate_deployment_yml - basic' do
    yml = kubernetes_method.generate_deployment_yml(@website, @website_location, {})

    assert_contains_deployment_yml(yml, @website, @website_location,
                                   requested_memory: @website.memory,
                                   limited_memory: @website.memory,
                                   with_probes: true)
  end

  test 'generate_deployment_yml - with replicas 2' do
    @website.configs ||= {}
    @website.configs['REPLICAS'] = 2
    @website.save!

    @website_location.reload

    yml = kubernetes_method.generate_deployment_yml(@website, @website_location, {})

    assert_contains_deployment_yml(yml, @website, @website_location,
                                   requested_memory: @website.memory,
                                   limited_memory: @website.memory,
                                   with_probes: true,
                                   replicas: 2)
  end

  test 'generate_deployment_yml - with persisted storage' do
    @website.storage_areas = ["/opt/data"]
    @website.save!
    @website_location.change_storage!(5)

    yml = kubernetes_method.generate_deployment_yml(@website, @website_location, {})

    assert_contains_deployment_yml(yml, @website, @website_location,
                                   requested_memory: @website.memory,
                                   limited_memory: @website.memory,
                                   with_probes: true,
                                   with_persistence: true)
  end

  test 'generate_persistence_volume_claim_yml - without extra storage' do
    yml = kubernetes_method.generate_persistence_volume_claim_yml(@website_location)

    assert_equal yml, ""
  end

  test 'generate_persistence_volume_claim_yml - with extra storage' do
    @website_location.change_storage!(3)
    yml = kubernetes_method.generate_persistence_volume_claim_yml(@website_location)

    assert_includes yml, "kind: PersistentVolumeClaim"
    assert_includes yml, "storage: 3Gi"
    assert_includes yml, "storageClassName: do-block-storage"
  end

  test 'generate_persistence_addon_volume_claim_yml' do
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['minimum_memory_mb'] = 100
    addon.obj['requires_persistence'] = true
    addon.obj['persistent_path'] = "/var/www"
    addon.obj['required_fields'] = ['persistent_path']
    addon.save!

    wa = WebsiteAddon.create(
      name: 'hi-world',
      account_type: 'second',
      website: @website,
      addon: addon,
      obj: {
        attrib: 'val1'
      },
      storage_gb: 4
    )

    yml = kubernetes_method.generate_persistence_addon_volume_claim_yml(wa)

    assert_includes yml, "name: website-addon-#{wa.id}-pvc"
    assert_includes yml, "kind: PersistentVolumeClaim"
    assert_includes yml, "storage: 4Gi"
    assert_includes yml, "storageClassName: do-block-storage"
  end

  test 'generate_deployment_yml - with skip port check' do
    @website.configs = {
      "SKIP_PORT_CHECK": "true"
    }
    @website.save!
    yml = kubernetes_method.generate_deployment_yml(@website, @website_location, {})

    assert_contains_deployment_yml(yml, @website, @website_location,
                                   requested_memory: @website.memory,
                                   limited_memory: @website.memory,
                                   with_probes: false)
  end

  # generate_deployment_addons_yml
  test 'generate_deployment_addons_yml - with no addon' do
    yml = kubernetes_method.generate_deployment_addons_yml([])

    assert_equal yml, ""
  end

  test 'generate_deployment_addons_yml - with single addon' do
    w = default_website

    Addon.destroy_all
    addon = Addon.create!(
      name: 'hello-redis',
      category: 'caching',
      obj: {
        name: "redis-caching",
        category: "caching",
        minimum_memory_mb: 50,
        protocol: "TCP",
        logo_filename: "logo.svg",
        documentation_filename: "README.md",
        image: "redis:alpine",
        target_port: 6379,
        required_fields: ["exposed_port"],
        env_variables: {},
        required_env_variables: []
      }
    )

    WebsiteAddon.create!(
      website: w,
      addon: addon,
      name: addon.name,
      account_type: 'second',
      obj: {

      }
    )

    yml = kubernetes_method.generate_deployment_addons_yml(w.website_addons.reload)

    assert_includes yml, "namespace: instance-#{w.id}"
    assert_includes yml, "app: hello-redis"
    assert_includes yml, "port: 6379"
    assert_includes yml, "targetPort: 6379"
    assert_includes yml, "containerPort: 6379"
    assert_includes yml, "image: redis:alpine"
    assert_includes yml, "memory: 100"
    assert_not_includes yml, "PersistentVolumeClaim"
  end

  test 'generate_deployment_addon_yml - with persistence' do
    w = default_website

    Addon.destroy_all
    addon = Addon.create!(
      name: 'hello-redis',
      category: 'caching',
      obj: {
        name: "redis-caching",
        category: "caching",
        minimum_memory_mb: 50,
        protocol: "TCP",
        logo_filename: "logo.svg",
        documentation_filename: "README.md",
        image: "redis:alpine",
        target_port: 6379,
        requires_persistence: true,
        persistent_path: "/var/www",
        required_fields: %w[exposed_port persistent_path],
        env_variables: {},
        required_env_variables: []
      }
    )

    WebsiteAddon.create!(
      website: w,
      addon: addon,
      name: addon.name,
      account_type: 'second',
      obj: {
        persistent_path: "/var/www"
      },
      storage_gb: 1
    )

    yml = kubernetes_method.generate_deployment_addons_yml(
      w.website_addons.reload,
      with_pvc_object: true
    )

    assert_includes yml, "kind: PersistentVolumeClaim"
    assert_includes yml, "storage: 1Gi"
  end

  test 'generate_deployment_addon_volumes_yml - without persistence' do
    w = default_website

    Addon.destroy_all
    addon = Addon.create!(
      name: 'hello-redis',
      category: 'caching',
      obj: {
        name: "redis-caching",
        category: "caching",
        minimum_memory_mb: 50,
        protocol: "TCP",
        logo_filename: "logo.svg",
        documentation_filename: "README.md",
        image: "redis:alpine",
        target_port: 6379,
        requires_persistence: false,
        required_fields: ["exposed_port"],
        env_variables: {},
        required_env_variables: []
      }
    )

    wa = WebsiteAddon.create!(
      website: w,
      addon: addon,
      name: addon.name,
      account_type: 'second',
      obj: {
        persistent_path: "/var/www"
      }
    )

    yml = kubernetes_method.generate_deployment_addon_volumes_yml(wa)

    assert yml == ""
  end

  test 'generate_deployment_addon_volumes_yml - with persistence' do
    w = default_website

    Addon.destroy_all
    addon = Addon.create!(
      name: 'hello-redis',
      category: 'caching',
      obj: {
        name: "redis-caching",
        category: "caching",
        minimum_memory_mb: 50,
        protocol: "TCP",
        logo_filename: "logo.svg",
        documentation_filename: "README.md",
        image: "redis:alpine",
        target_port: 6379,
        requires_persistence: true,
        persistent_path: "/var/www2",
        required_fields: %w[exposed_port persistent_path],
        env_variables: {},
        required_env_variables: []
      }
    )

    wa = WebsiteAddon.create!(
      website: w,
      addon: addon,
      name: addon.name,
      account_type: 'second',
      obj: {
        persistent_path: "/var/www2"
      },
      storage_gb: 2
    )

    yml = kubernetes_method.generate_deployment_addon_volumes_yml(wa)

    assert_includes yml, "claimName: website-addon-#{wa.id}-pvc"
    assert_includes yml, "'chmod 777 \"/var/www2\""
    assert_includes yml, "mountPath: \"/var/www2\""
  end

  test 'generate_deployment_addon_mount_paths_yml - with persistence' do
    w = default_website

    Addon.destroy_all
    addon = Addon.create!(
      name: 'hello-redis',
      category: 'caching',
      obj: {
        name: "redis-caching",
        category: "caching",
        minimum_memory_mb: 50,
        protocol: "TCP",
        logo_filename: "logo.svg",
        documentation_filename: "README.md",
        image: "redis:alpine",
        target_port: 6379,
        requires_persistence: true,
        persistent_path: "/var/www2",
        required_fields: %w[exposed_port persistent_path],
        env_variables: {},
        required_env_variables: []
      }
    )

    wa = WebsiteAddon.create!(
      website: w,
      addon: addon,
      name: addon.name,
      account_type: 'second',
      obj: {
        persistent_path: "/var/www2"
      },
      storage_gb: 2
    )

    yml = kubernetes_method.generate_deployment_addon_mount_paths_yml(wa)

    assert_includes yml, "mountPath: \"/var/www2\""
  end

  test 'generate_deployment_addon_mount_paths_yml - without persistence' do
    w = default_website

    Addon.destroy_all
    addon = Addon.create!(
      name: 'hello-redis',
      category: 'caching',
      obj: {
        name: "redis-caching",
        category: "caching",
        minimum_memory_mb: 50,
        protocol: "TCP",
        logo_filename: "logo.svg",
        documentation_filename: "README.md",
        image: "redis:alpine",
        target_port: 6379,
        required_fields: %w[exposed_port],
        env_variables: {},
        required_env_variables: []
      }
    )

    wa = WebsiteAddon.create!(
      website: w,
      addon: addon,
      name: addon.name,
      account_type: 'second',
      obj: {
        persistent_path: "/var/www2"
      },
      storage_gb: 2
    )

    yml = kubernetes_method.generate_deployment_addon_mount_paths_yml(wa)

    assert yml == ""
  end

  test 'generate_deployment_probes_yml - with probes' do
    yml = kubernetes_method.generate_deployment_probes_yml(
      with_readiness_probe: true,
      status_probe_path: @website.status_probe_path,
      status_probe_period: @website.status_probe_period
    )

    # assert_includes yml, "livenessProbe:"
    assert_includes yml, "path: /"
    assert_includes yml, "readinessProbe:"
    assert_includes yml, "periodSeconds: 20"
  end

  test 'generate_deployment_probes_yml - with probes, custom path' do
    @website.configs ||= {}
    @website.configs['STATUS_PROBE_PATH'] = '/status'
    yml = kubernetes_method.generate_deployment_probes_yml(
      with_readiness_probe: !@website.skip_port_check?,
      status_probe_path: @website.status_probe_path,
      status_probe_period: @website.status_probe_period
    )

    assert_includes yml, "path: /status"
    assert_includes yml, "readinessProbe:"
    assert_includes yml, "periodSeconds: 20"
  end

  test 'generate_deployment_probes_yml - with custom period seconds' do
    @website.configs ||= {}
    @website.configs['STATUS_PROBE_PERIOD'] = 55
    @website.save!
    yml = kubernetes_method.generate_deployment_probes_yml(
      with_readiness_probe: true,
      status_probe_path: @website.status_probe_path,
      status_probe_period: @website.status_probe_period
    )

    assert_includes yml, "periodSeconds: 55"
  end

  test 'generate_deployment_probes_yml - without probes' do
    @website.configs = {
      "SKIP_PORT_CHECK": "true"
    }
    @website.save!

    yml = kubernetes_method.generate_deployment_probes_yml(
      with_readiness_probe: !@website.skip_port_check?,
      status_probe_path: @website.status_probe_path,
      status_probe_period: @website.status_probe_period
    )

    assert_not_includes yml, "readinessProbe:"
  end

  def assert_contains_service_yml(yml, website, options = {})
    assert_includes yml, "kind: Service"
    assert_includes yml, "name: main-service"
    assert_includes yml, "namespace: #{kubernetes_method.namespace_of(website)}"
    assert_includes yml, "app: www"

    if options[:with_type]
      assert_includes yml, "type: #{options[:with_type]}"
    end
  end

  test 'generate_service_yml - basic' do
    yml = kubernetes_method.generate_service_yml(@website)

    assert_contains_service_yml(yml, @website, with_type: "ClusterIP")
  end

  test 'generate_service_yml - with custom domain' do
    w = default_custom_domain_website

    yml = kubernetes_method.generate_service_yml(w)

    assert_contains_service_yml(yml, w, with_type: "ClusterIP")
  end

  test 'certificate? - if certificate provided' do
    set_website_certs(@website)

    assert_equal kubernetes_method.certificate?(@website), true
  end

  test 'certificate? - if subdomain' do
    assert_equal kubernetes_method.certificate?(@website), true
  end

  test 'certificate_secret_name - if certificate provided' do
    set_website_certs(@website)

    assert_equal kubernetes_method.certificate_secret_name(@website), "manual-certificate"
  end

  test 'certificate_secret_name - if subdomain' do
    assert_equal kubernetes_method.certificate_secret_name(@website), "wildcard-certificate"
  end

  def assert_contains_certificate_secret(yml, secret_name, crt, key)
    assert_includes yml, "kind: Secret"
    assert_includes yml, "name: #{secret_name}"
    assert_includes yml, "type: kubernetes.io/tls"
    assert_includes yml, "tls.crt: #{crt}"
    assert_includes yml, "tls.key: #{key}"
  end

  test 'generate_manual_tls_secret_yml - with certificate' do
    set_website_certs(@website)

    cmd_get_crt = kubernetes_method.retrieve_file_cmd(path: "#{@website.repo_dir}cert/crt")
    tls_crt = IO.read("test/fixtures/certs/tls.crt")
    prepare_ssh_session(cmd_get_crt, tls_crt)

    cmd_get_key = kubernetes_method.retrieve_file_cmd(path: "#{@website.repo_dir}cert/key")
    tls_key = IO.read("test/fixtures/certs/tls.key")
    prepare_ssh_session(cmd_get_key, tls_key)

    crt_b64 = Base64.strict_encode64(tls_crt)
    key_b64 = Base64.strict_encode64(tls_key)

    assert_scripted do
      begin_ssh

      yml = kubernetes_method.generate_manual_tls_secret_yml(@website)
      assert_contains_certificate_secret(yml, "manual-certificate", crt_b64, key_b64)
    end
  end

  test 'generate_manual_tls_secret_yml - with missing crt should fail' do
    set_website_certs(@website)

    cmd_get_crt = kubernetes_method.retrieve_file_cmd(path: "#{@website.repo_dir}cert/crt")
    prepare_ssh_session(cmd_get_crt, "", 1)

    assert_scripted do
      begin_ssh

      kubernetes_method.generate_manual_tls_secret_yml(@website)

    rescue StandardError => e
      assert_includes e.to_s, "Failed to run retrieve_file_cmd"
    end
  end

  test 'generate_manual_tls_secret_yml - with missing crt key should fail' do
    set_website_certs(@website)

    cmd_get_crt = kubernetes_method.retrieve_file_cmd(path: "#{@website.repo_dir}cert/crt")
    prepare_ssh_session(cmd_get_crt, "")

    cmd_get_key = kubernetes_method.retrieve_file_cmd(path: "#{@website.repo_dir}cert/key")
    prepare_ssh_session(cmd_get_key, "", 1)

    assert_scripted do
      begin_ssh

      kubernetes_method.generate_manual_tls_secret_yml(@website)

    rescue StandardError => e
      assert_includes e.to_s, "Failed to run retrieve_file_cmd"
    end
  end

  test 'generate_manual_tls_secret_yml - without certificate' do
    @website.configs = {}
    @website.configs['SSL_CERTIFICATE_PATH'] = nil
    @website.configs['SSL_CERTIFICATE_KEY_PATH'] = nil
    @website.save!

    assert_equal kubernetes_method.generate_manual_tls_secret_yml(@website), ""
  end

  test 'generate_wildcard_subdomain_tls_secret_yaml' do
    @website.configs = {}
    @website.configs['SSL_CERTIFICATE_PATH'] = nil
    @website.configs['SSL_CERTIFICATE_KEY_PATH'] = nil
    @website.save!

    wl = @website.website_locations.first

    yml = kubernetes_method.generate_wildcard_subdomain_tls_secret_yaml(@website, wl)
    location_str_id = @website.website_locations.first.location.str_id

    crt_b64 = Base64.strict_encode64(IO.read("config/certs/test-wildcard-#{location_str_id}.crt"))
    key_b64 = Base64.strict_encode64(IO.read("config/certs/test-wildcard-#{location_str_id}.key"))

    assert_contains_certificate_secret(yml, "wildcard-certificate", crt_b64, key_b64)
  end

  def assert_contains_ingress_yml(yml, website, website_location, opts = {})
    domains = website_location.compute_domains

    assert_includes yml, "kind: Ingress"
    assert_includes yml, "name: main-ingress"
    assert_includes yml, "namespace: #{kubernetes_method.namespace_of(website)}"
    assert_includes yml, "ingress.class: \"nginx\""

    if opts[:ssl_redirect].present?
      assert_includes yml, "ingress.kubernetes.io/ssl-redirect: \"#{opts[:ssl_redirect]}\""
    end

    if opts[:limit_rpm].present?
      assert_includes yml, "ingress.kubernetes.io/limit-rpm: \"#{opts[:limit_rpm]}\""
    end

    domains.each do |domain|
      assert_includes yml, "- host: #{domain}"
    end

    if opts[:with_certificate_secret]
      assert_includes yml, "tls:"
    else
      assert_not_includes yml, "tls:"
    end
  end

  test 'node_available? - when no crash loop back' do
    prep = [
      {
        "status" => {
          "containerStatuses" => [
            {
              "lastState" => { "terminated" => { "reason" => "" } }
            }
          ]
        }
      }
    ]

    assert kubernetes_method.node_available?(instance_up_preparation: prep)
  end

  test 'node_available? - when crash loop back' do
    prep = [
      {
        "status" => {
          "containerStatuses" => [
            {
              "state" => { "waiting" => { "reason" => "CrashLoopBackOff" } }
            }
          ]
        }
      }
    ]

    assert_not kubernetes_method.node_available?(instance_up_preparation: prep)
  end

  test 'instance_up_cmd - all up' do
    prep = [
      {
        "status" => {
          "containerStatuses" => [
            {
              "ready" => true
            }
          ]
        }
      }
    ]

    result = kubernetes_method.instance_up_cmd(instance_up_preparation: prep)

    assert_equal result, "echo true | grep true"
  end

  test 'instance_up_cmd - not ready' do
    prep = [
      {
        "status" => {
          "containerStatuses" => [
            {
              "ready" => false
            }
          ]
        }
      }
    ]

    result = kubernetes_method.instance_up_cmd(instance_up_preparation: prep)

    assert_equal result, "echo false | grep true"
  end

  test 'instance_up_cmd - no ready attribute' do
    prep = [
      {
        "status" => {
          "containerStatuses" => [
            {
              "state" => {}
            }
          ]
        }
      }
    ]

    result = kubernetes_method.instance_up_cmd(instance_up_preparation: prep)

    assert_equal result, "echo false | grep true"
  end

  test 'instance_up_cmd - no pod' do
    prep = []

    result = kubernetes_method.instance_up_cmd(instance_up_preparation: prep)

    assert_equal result, "echo false | grep true"
  end

  test 'pods_contain_oom? - happy path without www' do
    pod = {
      "metadata" => {
        "labels" => {
          "app" => "www"
        }
      },
      "status" => {
        "containerStatuses" => [
          {
            "lastState" => { "terminated" => { "reason" => "OOMKilled" } }
          }
        ]
      }
    }

    assert kubernetes_method.pods_contain_oom?([pod])
  end

  test 'pods_contain_oom? - happy path with www' do
    pod = {
      "metadata" => {
        "labels" => {
          "app" => "www"
        }
      },
      "status" => {
        "containerStatuses" => [
          {
            "lastState" => { "terminated" => { "reason" => "OOMKilled" } }
          }
        ]
      }
    }

    assert kubernetes_method.pods_contain_oom?([{}, pod], "www")
  end

  test 'pods_contain_oom? - without www' do
    pod = {
      "metadata" => {
        "labels" => {
          "app" => "www"
        }
      },
      "status" => {
        "containerStatuses" => [
          {
            "lastState" => { "terminated" => { "reason" => "OOMKilled" } }
          }
        ]
      }
    }

    assert_equal kubernetes_method.pods_contain_oom?([{}, pod], "www2"), false
  end

  test 'contains_oom? - happy path' do
    prep = {
      "status" => {
        "containerStatuses" => [
          {
            "lastState" => { "terminated" => { "reason" => "OOMKilled" } }
          }
        ]
      }
    }

    assert kubernetes_method.contains_oom?(prep)
  end

  test 'contains_oom? - no oom' do
    prep = {
      "status" => {
        "containerStatuses" => [
          {
            "lastState" => { "terminated" => {} }
          }
        ]
      }
    }

    assert_equal kubernetes_method.contains_oom?(prep), false
  end

  test 'generate_ingress_yml' do
    assert_scripted do
      begin_ssh

      yml = kubernetes_method.generate_ingress_yml(@website, @website_location)

      assert_contains_ingress_yml(yml, @website, @website_location,
                                  with_certificate_secret: true,
                                  ssl_redirect: true,
                                  limit_rpm: 60 * 100)
    end
  end

  test 'generate_ingress_yml - without ssl redirect' do
    assert_scripted do
      begin_ssh

      yml = kubernetes_method.generate_ingress_yml(@website, @website_location)

      @website.configs = {
        'REDIR_HTTP_TO_HTTPS': false
      }
      @website.save!

      assert_contains_ingress_yml(yml, @website, @website_location,
                                  with_certificate_secret: true,
                                  ssl_redirect: false)
    end
  end

  test 'generate_ingress_yml - with ssl redirect if empty' do
    assert_scripted do
      begin_ssh

      yml = kubernetes_method.generate_ingress_yml(@website, @website_location)

      @website.configs = {
        'REDIR_HTTP_TO_HTTPS': ''
      }
      @website.save!

      assert_contains_ingress_yml(yml, @website, @website_location,
                                  with_certificate_secret: true,
                                  ssl_redirect: true)
    end
  end

  test 'generate_ingress_yml - with certificate' do
    set_website_certs(@website)

    assert_scripted do
      begin_ssh

      yml = kubernetes_method.generate_ingress_yml(@website, @website_location)

      assert_contains_ingress_yml(yml, @website, @website_location,
                                  with_certificate_secret: true,
                                  with_certificate_secret_name: "manual-certificate")
    end
  end

  test 'generate_rules_ingress_yml - happy path' do
    yml =
      kubernetes_method.generate_rules_ingress_yml(@website, nil, [{ hostname: 'myurl.com' }])

    assert_equal yml.scan(/myurl.com/).count, 1
  end

  test 'generate_instance_yml - basic' do
    cmd_get_dotenv = kubernetes_method.retrieve_dotenv_cmd(website: @website)
    prepare_ssh_session(cmd_get_dotenv, '')
    @website_location.change_storage!(3)

    assert_scripted do
      begin_ssh

      yml = kubernetes_method.generate_instance_yml(@website, @website_location,
                                                    with_namespace_object: true,
                                                    with_pvc_object: true)

      assert_includes yml, "kind: PersistentVolumeClaim"
      assert_includes yml, "storageClassName: do-block-storage"
      assert_contains_namespace_yml(yml, @website)
      assert_contains_deployment_yml(yml, @website, @website_location, with_probes: true)
      assert_contains_service_yml(yml, @website)
      assert_contains_ingress_yml(yml, @website, @website_location,
                                  with_certificate_secret: true)
    end
  end

  test 'generate_instance_yml - without namespace object/pvc' do
    cmd_get_dotenv = kubernetes_method.retrieve_dotenv_cmd(website: @website)
    prepare_ssh_session(cmd_get_dotenv, '')

    assert_scripted do
      begin_ssh

      yml = kubernetes_method.generate_instance_yml(@website, @website_location,
                                                    with_namespace_object: false,
                                                    with_pvc_object: false)

      assert_not_includes yml, "kind: PersistentVolumeClaim"
      assert_not_includes yml, "storageClassName: do-block-storage"
      assert_not_includes yml, "kind: Namespace"
      assert_contains_deployment_yml(yml, @website, @website_location, with_probes: true)
      assert_contains_service_yml(yml, @website)
      assert_contains_ingress_yml(yml, @website, @website_location,
                                  with_certificate_secret: true)
    end
  end

  test 'cmd_docker_registry_secret' do
    cloud_provider_manager = CloudProvider::Manager.instance
    cmd = kubernetes_method.cmd_docker_registry_secret(
      @website, cloud_provider_manager.docker_images_location
    )

    assert_includes cmd, "-n instance-#{@website.id} create secret docker-registry regcred"
    assert_includes cmd, "--docker-server=docker.io"
    assert_includes cmd, "--docker-username=test"
    assert_includes cmd, "--docker-email=test@openode.io"
  end

  test 'should_remove_namespace? - should not' do
    @website_location.change_storage!(2)
    assert_equal kubernetes_method.should_remove_namespace?(@website.reload), false
  end

  test 'should_remove_namespace? - should' do
    assert_equal kubernetes_method.should_remove_namespace?(@website.reload), true
  end

  test 'finalize - happy path' do
    @website.status = Website::STATUS_ONLINE
    @website.save!

    get_pods_json_content = IO.read('test/fixtures/kubernetes/1_pod_alive.json')
    prepare_get_pods_json(kubernetes_method, @website, @website_location, get_pods_json_content,
                          0)
    prepare_kubernetes_logs(kubernetes_method, "hello logs", 0,
                            website: @website,
                            website_location: @website_location,
                            pod_name: "www-deployment-5889df69dc-xg9xl",
                            nb_lines: 1_000)

    prepare_get_services_json(kubernetes_method, @website, @website_location,
                              IO.read('test/fixtures/kubernetes/get_services.json'))

    assert_scripted do
      begin_ssh

      kubernetes_method.finalize(
        website: @website,
        website_location: @website_location
      )

      exec = @website.reload.executions.last

      assert_equal exec.events.length, 3
      assert_equal exec.events[0]['update'], "hello logs"
      assert_equal exec.events[1]['update']['details']['result'], 'success'
      assert_includes exec.events[2]['update'], 'Final Deployment state: SUCCESS'

      assert_equal @website_location.reload.cluster_ip, '10.245.87.60'
    end
  end

  test 'analyse_pod_status_for_lack_memory - with killed' do
    status = {
      'lastState' => {
        'terminated' => {
          'reason' => 'OOMKilled'
        }
      }
    }

    result_msg = kubernetes_method.analyse_pod_status_for_lack_memory('testt', status)

    assert_includes result_msg, 'FATAL'
    assert_includes result_msg, 'Lack of memory detected'
  end

  test 'analyse_pod_status_for_lack_memory - without mem issue' do
    status = {}

    result_msg = kubernetes_method.analyse_pod_status_for_lack_memory('testt', status)

    assert_nil result_msg
  end

  # analyze_final_pods_state

  test 'analyze_final_pods_state - with killed' do
    pods = {
      'items' => [
        {
          'status' => {
            'containerStatuses' => [
              {
                'lastState' => {
                  'terminated' => {
                    'reason' => 'OOMKilled'
                  }
                }
              }
            ]
          }
        }
      ]
    }

    kubernetes_method.analyze_final_pods_state(pods)

    last_event = kubernetes_method.runner.execution.events.last
    assert_includes last_event['update'], 'Lack of memory'
  end

  test 'final_instance_details - with custom domain' do
    w = default_custom_domain_website
    website_location = w.website_locations.first

    assert_scripted do
      begin_ssh

      result_details = kubernetes_method.final_instance_details(
        website: w,
        website_location: website_location
      )

      expected_result = {
        "result" => "success",
        "url" => "http://www.what.is/",
        "CNAME Record" => 'usa.openode.io'
      }

      assert_equal result_details, expected_result
      assert_includes kubernetes_method.runner.execution.events.first['update'],
                      "The DNS documentation is available"
    end
  end

  test 'finalize - when failing should stop' do
    @website.status = Website::STATUS_OFFLINE
    @website.save!

    get_pods_json_content = IO.read('test/fixtures/kubernetes/1_pod_alive.json')
    prepare_get_pods_json(kubernetes_method, @website, @website_location, get_pods_json_content,
                          0)

    cmd = kubernetes_method.kubectl(
      website_location: @website_location,
      with_namespace: true,
      s_arguments: "get events -o json"
    )

    file_events =
      "test/fixtures/kubernetes/get_events.json"
    expected_result = IO.read(file_events)
    prepare_ssh_session(cmd, expected_result, 0)

    get_pods_json_content = IO.read('test/fixtures/kubernetes/1_pod_alive.json')
    prepare_get_pods_json(kubernetes_method, @website, @website_location, get_pods_json_content,
                          0, "get pod -l app=www")

    netstat_result = "Active Internet connections (only servers)\n"\
      "Proto Recv-Q Send-Q Local Address           Foreign Address         State       \n"\
      "tcp        0      0 127.0.0.1:3000          0.0.0.0:*               LISTEN"

    prepare_kubernetes_custom_cmd(kubernetes_method,
                                  "netstat -tl",
                                  netstat_result,
                                  0,
                                  website: @website,
                                  website_location: @website_location,
                                  pod_name: "www-deployment-5889df69dc-xg9xl")

    prepare_kubernetes_logs(kubernetes_method, "hello logs", 0,
                            website: @website,
                            website_location: @website_location,
                            pod_name: "www-deployment-5889df69dc-xg9xl",
                            nb_lines: 1_000)
    prepare_make_secret(kubernetes_method, @website, @website_location, "success")
    prepare_get_dotenv(kubernetes_method, @website, "VAR=123")

    prepare_action_yml(kubernetes_method, @website_location, "apply.yml",
                       "delete --timeout 30s  -f apply.yml", 'success')

    assert_scripted do
      begin_ssh

      kubernetes_method.finalize(
        website: @website,
        website_location: @website_location
      )

      event = kubernetes_method.runner.execution.events.first
      expected_event = "entity: Ingress, reason: AddedOrUpdated, message: Configuration for"
      assert_includes event.dig('update'), expected_event

      port_event = kubernetes_method.runner.execution.events[1]
      assert_includes port_event.dig('update'), "IMPORTANT: HTTP port (80) NOT listening"
    end
  end

  test 'kubectl_yml_action - with kubectl options' do
    prepare_action_yml(kubernetes_method, @website_location, "apply.yml",
                       "delete --timeout 30s  -f apply.yml", 'success')

    assert_scripted do
      begin_ssh

      kubernetes_method.kubectl_yml_action(
        @website_location, "delete", "", kubectl_options: " --timeout 30s "
      )
    end
  end

  test 'kubectl_yml_action - with options_on_last_retry and last trial' do
    prepare_action_yml(kubernetes_method, @website_location, "apply.yml",
                       "delete --force  -f apply.yml", 'success')

    assert_scripted do
      begin_ssh

      kubernetes_method.kubectl_yml_action(
        @website_location, "delete", "", options_on_last_retry: " --force ", last_trial: true
      )
    end
  end

  test 'kubectl_yml_action - with options_on_last_retry and last trial false' do
    prepare_action_yml(kubernetes_method, @website_location, "apply.yml",
                       "delete -f apply.yml", 'success')

    assert_scripted do
      begin_ssh

      kubernetes_method.kubectl_yml_action(
        @website_location, "delete", "", options_on_last_retry: " --force "
      )
    end
  end

  test 'wait_for_service_load_balancer - available' do
    w = default_custom_domain_website
    website_location = w.website_locations.first

    file_services =
      "test/fixtures/kubernetes/services-with-resolved-load-balancer.json"
    result = IO.read(file_services)
    prepare_get_services_namespaced_happy(kubernetes_method, website_location,
                                          result)

    assert_scripted do
      begin_ssh

      load_balancer =
        kubernetes_method.wait_for_service_load_balancer(w, website_location)

      assert_equal load_balancer, "6ojq59kjlk.lb.c1.bhs5.k8s.ovh.net"
    end
  end

  # volumes, persistence
  test 'storage_volumes? when having volumes' do
    w = default_website
    wl = default_website_location
    w.storage_areas = ["/opt/data/what"]
    w.save!

    assert_equal wl.extra_storage, 1

    # storage_volumes
    assert_equal kubernetes_method.storage_volumes?(w, wl), true
  end

  test 'storage_volumes? when no storage area' do
    w = default_website
    wl = default_website_location
    w.storage_areas = []
    w.save!

    assert_equal wl.extra_storage, 1

    # storage_volumes
    assert_equal kubernetes_method.storage_volumes?(w, wl), false
  end

  test 'storage_volumes? when no extra storage' do
    w = default_website
    wl = default_website_location
    w.storage_areas = ["/what"]
    w.save!

    wl.change_storage!(-1)
    assert_equal wl.extra_storage, 0

    # storage_volumes
    assert_equal kubernetes_method.storage_volumes?(w, wl), false
  end

  test 'pods_contain_status_message? - happy path' do
    file_services =
      "test/fixtures/kubernetes/get_pods_not_enough_memory.json"
    pods = JSON.parse(IO.read(file_services))

    result = kubernetes_method.pods_contain_status_message?(pods, "insufficient memory")
    assert result
  end

  test 'pods_contain_status_message? - does not contain' do
    file_services =
      "test/fixtures/kubernetes/1_pod_alive.json"
    pods = JSON.parse(IO.read(file_services))

    result = kubernetes_method.pods_contain_status_message?(pods, "insufficient memory")
    assert_not result
  end

  test 'pods_contain_status_message? - no items' do
    result = kubernetes_method.pods_contain_status_message?({}, "insufficient memory")
    assert_not result
  end

  test 'top - without namespace' do
    top = "NAME                              CPU(cores)   MEMORY(bytes)   \n" \
      "www-deployment-675ff8d89c-zbc9z   1m           37Mi"

    result = kubernetes_method.top(top)

    er = [
      {
        service: "www-deployment-675ff8d89c-zbc9z",
        cpu_raw: "1m",
        memory_raw: "37Mi",
        memory: 37
      }
    ]

    assert_equal result, er
  end

  test 'top - with namespace' do
    top = "NAMESPACE NAME                              CPU(cores)   MEMORY(bytes)   \n" \
      "instance-24156   www-deployment-6744df5b9-ccscb    1m           13Mi            \n" \
      "instance-24368   www-deployment-566d6fd9c8-vz55r   1m           72Mi"

    result = kubernetes_method.top(top)

    expected_r1 = {
      service: "www-deployment-6744df5b9-ccscb",
      cpu_raw: "1m",
      memory_raw: "13Mi",
      memory: 13,
      namespace: "instance-24156"
    }

    expected_r2 = {
      service: "www-deployment-566d6fd9c8-vz55r",
      cpu_raw: "1m",
      memory_raw: "72Mi",
      memory: 72,
      namespace: "instance-24368"
    }

    assert_equal result.first, expected_r1
    assert_equal result.last, expected_r2
  end

  test 'auto_should_bump_plan_to - should bump' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "first"
    w.auto_account_types_history = nil
    w.save

    result = kubernetes_method.auto_should_bump_plan_to(w)

    assert_equal result, "second"
  end

  test 'auto_should_bump_plan_to - should bump, skip history' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "first"
    w.auto_account_types_history = %w[second third]
    w.save

    result = kubernetes_method.auto_should_bump_plan_to(w)

    assert_equal result, "fourth"
  end

  test 'auto_init - happy path' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "first"
    w.auto_account_types_history = ["second"]
    w.save

    kubernetes_method.auto_init(w)

    w.reload

    assert_equal w.auto_account_type, "first"
    assert_equal w.auto_account_types_history, ["first"]
  end

  test 'auto_finalize - happy path' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "first"
    w.auto_account_types_history = %w[second third]
    w.save

    kubernetes_method.auto_finalize(w)

    w.reload

    assert_equal w.auto_account_type, "first"
    assert_equal w.auto_account_types_history, ["second"]
  end

  test 'auto_manage_memory - oom' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "first"
    w.auto_account_types_history = nil
    w.save

    pod = {
      "metadata" => {
        "labels" => {
          "app" => "www"
        }
      },
      "status" => {
        "containerStatuses" => [
          {
            "lastState" => { "terminated" => { "reason" => "OOMKilled" } }
          }
        ]
      }
    }

    w.deployments.create!(status: 'success', obj: { image_name_tag: "docker/myimage" })

    prepare_action_yml(kubernetes_method, w.website_locations.first, "apply.yml",
                       "apply -f apply.yml", 'success')

    assert_scripted do
      begin_ssh

      result = kubernetes_method.auto_manage_memory(w, pod)

      assert_equal result[:stdout], "success"

      w.reload

      assert_equal w.auto_account_type, "second"
      assert_equal w.auto_account_types_history, ["second"]

      assert_includes w.events.last.obj.dig('title'), "Auto Mem"
    end
  end

  test 'auto_manage_memory - should decrease' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "third"
    w.auto_account_types_history = nil
    w.save

    pod = {
      "metadata" => {
        "labels" => {
          "app" => "www"
        }
      },
      "status" => {
        "containerStatuses" => [
          {
            "lastState" => { "terminated" => { "reason" => "" } }
          }
        ]
      }
    }
    top = "NAMESPACE NAME                              CPU(cores)   MEMORY(bytes)   \n" \
      "instance-24156   www-deployment-6744df5b9-ccscb    1m           13Mi            \n" \
      "instance-#{w.id}   www-deployment-566d6fd9c8-vz55r   1m           72Mi"

    w.deployments.create!(status: 'success', obj: { image_name_tag: "docker/myimage" })

    prepare_action_yml(kubernetes_method, w.website_locations.first, "apply.yml",
                       "apply -f apply.yml", 'success')

    assert_scripted do
      begin_ssh

      result = kubernetes_method.auto_manage_memory(w, pod, top)

      assert_equal result[:stdout], "success"

      w.reload

      assert_equal w.auto_account_type, "second"
      assert_equal w.auto_account_types_history, ["second"]
    end
  end

  test 'auto_should_decrease_plan_to - should decrease' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "third"
    w.auto_account_types_history = nil
    w.save

    top = "NAMESPACE NAME                              CPU(cores)   MEMORY(bytes)   \n" \
      "instance-24156   www-deployment-6744df5b9-ccscb    1m           13Mi            \n" \
      "instance-#{w.id}   www-deployment-566d6fd9c8-vz55r   1m           72Mi"

    result = kubernetes_method.auto_should_decrease_plan_to(w, top)

    assert_equal result, "second"
  end

  test 'auto_should_decrease_plan_to - should not decrease if same' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "third"
    w.auto_account_types_history = %w[first second]
    w.save

    top = "NAMESPACE NAME                              CPU(cores)   MEMORY(bytes)   \n" \
      "instance-24156   www-deployment-6744df5b9-ccscb    1m           13Mi            \n" \
      "instance-#{w.id}   www-deployment-566d6fd9c8-vz55r   1m           72Mi"

    result = kubernetes_method.auto_should_decrease_plan_to(w, top)

    assert_nil result
  end

  test 'auto_should_decrease_plan_to - should not decrease if plan larger' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "third"
    w.auto_account_types_history = %w[first second third]
    w.save

    top = "NAMESPACE NAME                              CPU(cores)   MEMORY(bytes)   \n" \
      "instance-24156   www-deployment-6744df5b9-ccscb    1m           13Mi            \n" \
      "instance-#{w.id}   www-deployment-566d6fd9c8-vz55r   1m           72Mi"

    result = kubernetes_method.auto_should_decrease_plan_to(w, top)

    assert_nil result
  end

  test 'auto_should_decrease_plan_to - top not yet available' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "third"
    w.auto_account_types_history = nil
    w.save

    top = "NAMESPACE NAME                              CPU(cores)   MEMORY(bytes)   \n" \
      "instance-24156   www-deployment-6744df5b9-ccscb    1m           13Mi            \n" \
      "instance-#{w.id}   www-deployment-566d6fd9c8-vz55r   1m           0Mi"

    result = kubernetes_method.auto_should_decrease_plan_to(w, top)

    assert_equal result, nil
  end

  test 'auto_should_decrease_plan_to - do nothing if the same' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "second"
    w.auto_account_types_history = nil
    w.save

    top = "NAMESPACE NAME                              CPU(cores)   MEMORY(bytes)   \n" \
      "instance-24156   www-deployment-6744df5b9-ccscb    1m           13Mi            \n" \
      "instance-#{w.id}   www-deployment-566d6fd9c8-vz55r   1m           72Mi"

    result = kubernetes_method.auto_should_decrease_plan_to(w, top)

    assert_equal result, nil
  end

  test 'auto_should_decrease_plan_to - avoid taking already used account type' do
    w = default_website
    w.account_type = "auto"
    w.auto_account_type = "sixth"
    w.auto_account_types_history = %w[second third sixth]
    w.save

    top = "NAMESPACE NAME                              CPU(cores)   MEMORY(bytes)   \n" \
      "instance-24156   www-deployment-6744df5b9-ccscb    1m           13Mi            \n" \
      "instance-#{w.id}   www-deployment-566d6fd9c8-vz55r   1m           72Mi"

    result = kubernetes_method.auto_should_decrease_plan_to(w, top)

    assert_equal result, "fourth"
  end
end
