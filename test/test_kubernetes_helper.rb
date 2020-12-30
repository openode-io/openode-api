
class ActiveSupport::TestCase
  def prepare_make_namespace(kubernetes_method, website, website_location, result_expected)
    cmd_create_secret = kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments:
        "create namespace instance-#{website.id}"
    )

    prepare_ssh_session(cmd_create_secret, result_expected)
  end

  def prepare_make_secret(kubernetes_method, website, website_location, result_expected)
    cmd_create_secret = kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments:
        " -n instance-#{website.id} create secret docker-registry regcred " \
        "--docker-server=docker.io " \
        "--docker-username=test --docker-password=t123456 " \
        "--docker-email=test@openode.io "
    )

    prepare_ssh_session(cmd_create_secret, result_expected)
  end

  def prepare_check_repo_size(_kubernetes_method, website, expected_result)
    prepare_ssh_session("du -bs /home/#{website.user_id}/#{website.site_name}/", expected_result)
  end

  def prepare_build_image(_kubernetes_method, website, deployment, expected_result)
    timeout_part = "timeout " \
                   "#{DeploymentMethod::Util::InstanceImageManager::MAX_BUILD_TIMEOUT}s "

    build_cmd = "sudo #{timeout_part}docker build -t docker.io/openode_prod/testkubernetes-type:"

    prepare_ssh_session("cd /home/#{website.user_id}/#{website.site_name}/ && " \
                        "#{build_cmd}" \
                        "#{website.site_name}--#{website.id}--#{deployment.id} .",
                        expected_result)
  end

  def prepare_push_image(_kubernetes_method, website, deployment, expected_result)
    prepare_ssh_session("echo t123456 | sudo docker login -u test docker.io --password-stdin && " \
                        "sudo docker push docker.io/openode_prod/testkubernetes-type:" \
                        "#{website.site_name}--#{website.id}--#{deployment.id}",
                        expected_result)
  end

  def prepare_get_dotenv(_kubernetes_method, website, expected_result)
    prepare_ssh_session("cat /home/#{website.user_id}/#{website.site_name}/.env",
                        expected_result)
  end

  def prepare_action_yml(kubernetes_method, website_location, filename, s_arguments,
                         expected_result, expected_exit_code = 0)
    DeploymentMethod::Kubernetes.set_kubectl_file_path(filename)

    begin_sftp

    cmd = kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments: s_arguments
    )
    puts "cmd == #{cmd}"
    prepare_ssh_session(cmd, expected_result, expected_exit_code)

    prepare_ssh_session("rm -rf \"#{filename}\" ; ", "")
  end

  def prepare_get_pods_json(kubernetes_method, website, website_location, expected_result,
                            expected_exit_code, get_pod_part = "get pods")
    cmd = kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments: "-n instance-#{website.id} #{get_pod_part} -o json"
    )

    prepare_ssh_session(cmd, expected_result, expected_exit_code)
  end

  def prepare_get_services_json(kubernetes_method, website, website_location, expected_result,
                                expected_exit_code = 0)
    cmd = kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments: "-n instance-#{website.id} get services -o json"
    )

    prepare_ssh_session(cmd, expected_result, expected_exit_code)
  end

  def prepare_kubernetes_logs(kubernetes_method,
                              expected_result,
                              expected_exit_code,
                              opts = {})
    cmd = kubernetes_method.kubectl(
      website_location: opts[:website_location],
      s_arguments: "-n instance-#{opts[:website].id} logs -l app=www" \
                    " --tail=#{opts[:nb_lines]}"
    )

    prepare_ssh_session(cmd, expected_result, expected_exit_code)
  end

  def prepare_kubernetes_custom_cmd(kubernetes_method,
                                    cmd,
                                    expected_result,
                                    expected_exit_code,
                                    opts = {})
    # exec www-deployment-5889df69dc-xg9xl -- netstat -tl
    cmd = kubernetes_method.kubectl(
      website_location: opts[:website_location],
      s_arguments: "-n instance-#{opts[:website].id} exec #{opts[:pod_name]}" \
                    " -- #{cmd}"
    )

    prepare_ssh_session(cmd, expected_result, expected_exit_code)
  end

  def prepare_instance_up(_kubernetes_method, _website, _website_location, expected_result,
                          expected_exit_code = 0)

    prepare_ssh_session("echo true | grep true", expected_result, expected_exit_code)
  end

  def prepare_get_services_default_happy(kubernetes_method, website_location)
    cmd = kubernetes_method.kubectl(
      website_location: website_location,
      with_namespace: false,
      s_arguments: "get services -o json"
    )

    result = IO.read(
      'test/fixtures/kubernetes/get-default-services-with-nginx-controller.json'
    )
    prepare_ssh_session(cmd, result)
  end

  def prepare_get_services_namespaced_happy(kubernetes_method, website_location,
                                            expected_result)
    cmd = kubernetes_method.kubectl(
      website_location: website_location,
      with_namespace: true,
      s_arguments: "get services -o json"
    )

    prepare_ssh_session(cmd, expected_result)
  end

  def get_kubernetes_method(website)
    runner = prepare_kubernetes_runner(website, website.website_locations.first)

    runner.get_execution_method
  end
end
