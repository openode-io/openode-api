
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
        "--docker-server=https://index.docker.io/v1/ " \
        "--docker-username=test --docker-password=t123456 " \
        "--docker-email=test@openode.io "
    )

    prepare_ssh_session(cmd_create_secret, result_expected)
  end

  def prepare_check_repo_size(_kubernetes_method, website, expected_result)
    prepare_ssh_session("du -bs /home/#{website.user_id}/#{website.site_name}/", expected_result)
  end

  def prepare_build_image(_kubernetes_method, website, deployment, expected_result)
    prepare_ssh_session("cd /home/#{website.user_id}/#{website.site_name}/ && " \
                        "sudo docker build -t test/openode_prod:" \
                        "#{website.site_name}--#{website.id}--#{deployment.id} .",
                        expected_result)
  end

  def prepare_push_image(_kubernetes_method, website, deployment, expected_result)
    prepare_ssh_session("echo t123456 | sudo docker login -u test --password-stdin && " \
                        "sudo docker push test/openode_prod:" \
                        "#{website.site_name}--#{website.id}--#{deployment.id}",
                        expected_result)
  end

  def prepare_get_dotenv(_kubernetes_method, website, expected_result)
    prepare_ssh_session("cat /home/#{website.user_id}/#{website.site_name}/.env",
                        expected_result)
  end

  def prepare_action_yml(kubernetes_method, website_location, filename, s_arguments,
                         expected_result)
    DeploymentMethod::Kubernetes.set_kubectl_file_path(filename)

    begin_sftp

    cmd = kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments: s_arguments
    )
    prepare_ssh_session(cmd, expected_result)

    prepare_ssh_session("rm -rf \"#{filename}\" ; ", "")
  end

  def prepare_get_pods_json(kubernetes_method, website, website_location, expected_result,
                            expected_exit_code)
    cmd = kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments: "-n instance-#{website.id} get pods -o json"
    )

    prepare_ssh_session(cmd, expected_result, expected_exit_code)
  end

  def prepare_kubernetes_logs(kubernetes_method,
                              expected_result,
                              expected_exit_code,
                              opts = {})
    cmd = kubernetes_method.kubectl(
      website_location: opts[:website_location],
      s_arguments: "-n instance-#{opts[:website].id} logs #{opts[:pod_name]}" \
                    " --tail=#{opts[:nb_lines]}"
    )

    prepare_ssh_session(cmd, expected_result, expected_exit_code)
  end

  def prepare_node_alive(kubernetes_method, website, website_location, expected_result,
                         expected_exit_code)
    cmd_node_alive = kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments: "-n instance-#{website.id} get pods " \
                    "-o=jsonpath='{.items[*].status.containerStatuses[*].state.waiting}'" \
                    " | grep \"CrashLoopBackOff\""
    )

    prepare_ssh_session(cmd_node_alive, expected_result, expected_exit_code)
  end

  def prepare_instance_up(kubernetes_method, website, website_location, expected_result,
                          expected_exit_code = 0)
    cmd_instance_up = kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments: "-n instance-#{website.id} get pods " \
                    "-o=jsonpath='{.items[*].status.containerStatuses[*].ready}'" \
                    " | grep -v false"
    )

    prepare_ssh_session(cmd_instance_up, expected_result, expected_exit_code)
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
end
