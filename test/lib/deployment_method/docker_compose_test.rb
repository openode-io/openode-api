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
end
