require 'test_helper'

class DockerComposeTest < ActiveSupport::TestCase

  def setup

  end

  # default_docker_compose_file

  test "default_docker_compose_file without env file" do
    result = DeploymentMethod::DockerCompose.default_docker_compose_file

    assert_equal result.include?("version: '3'"), true
    assert_equal result.include?("# env_file:"), true
  end

  test "default_docker_compose_file with env file" do
    result = DeploymentMethod::DockerCompose.default_docker_compose_file({
      with_env_file: true
    })

    assert_equal result.include?("version: '3'"), true
    assert_equal result.include?("    env_file:"), true
  end

  # logs
  test "logs should fail if missing container id" do
    docker_compose = DeploymentMethod::DockerCompose.new

    begin
      docker_compose.logs({ nb_lines: 2 })
      assert false
    rescue
    end
  end

  test "logs should fail if missing nb_lines id" do
    docker_compose = DeploymentMethod::DockerCompose.new

    begin
      docker_compose.logs({ container_id: "1234" })
      assert false
    rescue
    end
  end

  test "logs should provide command if proper params" do
    docker_compose = DeploymentMethod::DockerCompose.new

    cmd = docker_compose.logs({ container_id: "1234", nb_lines: 10 })

    assert_includes cmd, "docker exec 1234 docker-compose logs"
    assert_includes cmd, "=10"
  end

  test "should have change dir and node" do
    dep_method = DeploymentMethod::DockerCompose.new

    result = dep_method.files_listing({ path: "/home/" })
    assert_includes result, "cd #{DeploymentMethod::DockerCompose::REMOTE_PATH_API_LIB} &&"
    assert_includes result, "node -e"
  end

  test "should be single line" do
    dep_method = DeploymentMethod::DockerCompose.new

    result = dep_method.files_listing({ path: "/home/" })
    assert_equal result.lines.count, 1
  end

  test "delete files generate proper command" do
    dep_method = DeploymentMethod::DockerCompose.new

    result = dep_method.delete_files({ files: ["/home/4/test.txt", "/home/what/isthat"] })
    assert_equal result, "rm -rf \"/home/4/test.txt\" ; rm -rf \"/home/what/isthat\" ; "
  end

  test "validate_docker_compose! with default docker compose" do
    begin
      dock_compose_str = DeploymentMethod::DockerCompose.default_docker_compose_file
      DeploymentMethod::DockerCompose.validate_docker_compose!(dock_compose_str)
    rescue
      assert false
    end
  end

  test "validate_docker_compose! with invalid docker compose" do
    begin
      dock_compose_str = "version: '3'
services:
  www:

    volumes:
      - /opt/app/:/opt/app/
    privileged: true
    ports:
      - '80:80'
    build:
      context: ."
      DeploymentMethod::DockerCompose.validate_docker_compose!(dock_compose_str)
      assert false
    rescue
    end
  end

  test "port_info_for_new_deployment first time" do
    website = default_website
    web_loc = website.website_locations.first
    web_loc.allocate_ports!
    dep_method = DeploymentMethod::DockerCompose.new

    result = dep_method.port_info_for_new_deployment(web_loc)

    assert_equal result[:port], web_loc.port
    assert_equal result[:attribute], "port"
    assert_equal result[:suffix_container_name], ""
  end

  test "port_info_for_new_deployment running on first port" do
    website = default_website
    web_loc = website.website_locations.first
    web_loc.allocate_ports!
    web_loc.running_port = web_loc.port
    web_loc.save!
    dep_method = DeploymentMethod::DockerCompose.new

    result = dep_method.port_info_for_new_deployment(web_loc)

    assert_equal result[:port], web_loc.second_port
    assert_equal result[:attribute], "second_port"
    assert_equal result[:suffix_container_name], "--2"
  end

  test "port_info_for_new_deployment running on second port" do
    website = default_website
    web_loc = website.website_locations.first
    web_loc.allocate_ports!
    web_loc.running_port = web_loc.second_port
    web_loc.save!
    dep_method = DeploymentMethod::DockerCompose.new

    result = dep_method.port_info_for_new_deployment(web_loc)

    assert_equal result[:port], web_loc.port
    assert_equal result[:attribute], "port"
    assert_equal result[:suffix_container_name], ""
  end

  test "send crontab without crontab provided" do
    set_dummy_secrets_to(LocationServer.all)
    website = default_website
    website.crontab = ""
    website.save!
    runner = DeploymentMethod::Runner.new("docker", "cloud", dummy_ssh_configs)

    begin_sftp
    runner.execute([
      {
        cmd_name: "send_crontab", options: { is_complex: true, website: website }
      }
    ])
    
    assert_equal Remote::Sftp.get_test_uploaded_files.length, 0
  end

  test "parse_global_containers" do
    set_dummy_secrets_to(LocationServer.all)
    website = default_website
    runner = DeploymentMethod::Runner.new("docker", "cloud", dummy_ssh_configs)
    dep_method = runner.get_deployment_method

    cmd = "docker ps --format \"{{.ID}};{{.Image}};{{.Command}};{{.CreatedAt}};{{.RunningFor}};{{.Ports}};{{.Status}};{{.Size}};{{.Names}};{{.Labels}};{{.Mounts}}\""
    prepare_ssh_session(cmd, IO.read("test/fixtures/docker/global_containers.txt"))

    assert_scripted do
      begin_ssh
      result = dep_method.parse_global_containers

      assert_equal result.length, 33
      assert_equal result[10][:ID], "b3621dd9d4dd"
      assert_equal result[10][:Ports], "2375-2376/tcp, 127.0.0.1:33121->80/tcp"
    end
  end
end
