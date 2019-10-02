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
    web_loc = default_website_location
    web_loc.allocate_ports!
    dep_method = DeploymentMethod::DockerCompose.new

    result = dep_method.port_info_for_new_deployment(web_loc)

    assert_equal result[:port], web_loc.port
    assert_equal result[:attribute], "port"
    assert_equal result[:suffix_container_name], ""
  end

  test "port_info_for_new_deployment running on first port" do
    website = default_website
    web_loc = default_website_location
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
    web_loc = default_website_location
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

  def expect_global_container(dep_method)
    cmd = dep_method.global_containers({})
    prepare_ssh_session(cmd, IO.read("test/fixtures/docker/global_containers.txt"))
  end

  test "parse_global_containers" do
    set_dummy_secrets_to(LocationServer.all)
    website = default_website
    runner = DeploymentMethod::Runner.new("docker", "cloud", dummy_ssh_configs)
    dep_method = runner.get_deployment_method

    expect_global_container(dep_method)

    assert_scripted do
      begin_ssh
      result = dep_method.parse_global_containers

      assert_equal result.length, 33
      assert_equal result[10][:ID], "b3621dd9d4dd"
      assert_equal result[10][:Ports], "2375-2376/tcp, 127.0.0.1:33121->80/tcp"
    end
  end

  test "find_containers_by_ports" do
    set_dummy_secrets_to(LocationServer.all)
    website = default_website
    runner = DeploymentMethod::Runner.new("docker", "cloud", dummy_ssh_configs)
    dep_method = runner.get_deployment_method

    cmd = dep_method.global_containers({})
    prepare_ssh_session(cmd, IO.read("test/fixtures/docker/global_containers.txt"))

    assert_scripted do
      begin_ssh
      result = dep_method.find_containers_by_ports({ ports: [33121, 47877] })

      assert_equal result.length, 2
      assert_equal result[0][:ID], "b3621dd9d4dd"
      assert_equal result[1][:ID], "b5f9d6f40129"
    end
  end

  test "kill_global_containers_by_ports" do
    set_dummy_secrets_to(LocationServer.all)
    website = default_website
    runner = DeploymentMethod::Runner.new("docker", "cloud", dummy_ssh_configs)
    dep_method = runner.get_deployment_method

    cmd = dep_method.global_containers({})
    prepare_ssh_session(cmd, IO.read("test/fixtures/docker/global_containers.txt"))
    prepare_ssh_session(dep_method.kill_global_container({ id: "b3621dd9d4dd" }), "killed b3621dd9d4dd")
    prepare_ssh_session(dep_method.kill_global_container({ id: "b5f9d6f40129" }), "killed b5f9d6f40129")

    assert_scripted do
      begin_ssh
      result = dep_method.kill_global_containers_by_ports({ ports: [33121, 47877] })

      assert_equal result.length, 2
      assert_equal result[0], "killed b3621dd9d4dd"
      assert_equal result[1], "killed b5f9d6f40129"
    end
  end

  def docker_compose_method(website = default_website, website_location = default_website_location)
    configs = dummy_ssh_configs
    puts "website ? #{default_website}"
    configs[:website] = website
    configs[:website_location] = website_location
    puts "configs #{configs.inspect}"

    runner = DeploymentMethod::Runner.new("docker", "cloud", configs)
    runner.get_deployment_method
  end

  test "prepare_dind_compose_image" do
    set_dummy_secrets_to(LocationServer.all)
    dep_method = docker_compose_method

    cmd = dep_method.prepare_dind_compose_image({})
    assert_includes cmd, "docker build -f "
    assert_includes cmd, "-t dind-with-docker-compose ."
  end

  test "front_crontainer_name" do
    website = default_website
    dep_method = docker_compose_method(website)

    cmd = dep_method.front_crontainer_name({ website: website, port_info: { suffix_container_name: "--2" } })
    assert_equal cmd, "#{website.user_id}--#{website.site_name}--2"
  end

  test "front_crontainer without resources limit" do
    website = default_website
    website_location = default_website_location
    dep_method = docker_compose_method

    options = {
      website: website,
      website_location: website_location,
      in_port: 80,
      limit_resources: false
    }
    cmd = dep_method.front_container(options)
    expected_cmd = 
      "docker run -w=/opt/app/ -d -v #{website.repo_dir}:/opt/app/ --name " +
      "#{website.user_id}--#{website.site_name} -p 127.0.0.1:11003:80  --privileged dind-with-docker-compose:latest"
    assert_equal cmd, expected_cmd
  end

  test "front_crontainer with resources limit" do
    website = default_website
    website_location = default_website_location
    dep_method = docker_compose_method

    options = {
      website: website,
      website_location: website_location,
      in_port: 80,
      limit_resources: true
    }
    cmd = dep_method.front_container(options)
    expected_cmd = 
      "docker run -w=/opt/app/ -d -v #{website.repo_dir}:/opt/app/ --name " +
      "#{website.user_id}--#{website.site_name} -p 127.0.0.1:11003:80  -m 350MB --cpus=1  --privileged dind-with-docker-compose:latest"
    assert_equal cmd, expected_cmd
  end

  test "docker_compose" do
    website = default_website
    website_location = default_website_location
    dep_method = docker_compose_method
    
    cmd = dep_method.docker_compose({ front_container_id: "123456789" })
    assert_includes cmd, "docker exec 123456789 docker-compose up -d"
  end

  test "verify_can_deploy" do
    website = default_website
    website_location = default_website_location
    dep_method = docker_compose_method
    
    cmd_get_docker_compose = dep_method.get_file({ repo_dir: website.repo_dir, file: "docker-compose.yml"})
    basic_docker_compose = IO.read("test/fixtures/docker/docker-compose.txt")
    prepare_ssh_session(cmd_get_docker_compose, basic_docker_compose)

    assert_scripted do
      begin_ssh
      dep_method.verify_can_deploy({ website: website, website_location: website_location })
    end
  end

  test "initialization without crontab" do
    website = default_website
    website.crontab = ""
    website.save
    website_location = default_website_location
    dep_method = docker_compose_method
    
    cmd_get_docker_compose = dep_method.get_file({ repo_dir: website.repo_dir, file: "docker-compose.yml"})
    prepare_ssh_session(dep_method.prepare_dind_compose_image, "empty")
    prepare_ssh_session("true", "empty")

    assert_scripted do
      begin_ssh
      dep_method.initialization({ website: website, website_location: website_location })
    end
  end

  test "launch" do
    website = default_website
    website.crontab = ""
    website.save
    website_location = default_website_location
    dep_method = docker_compose_method
    
    cmd_get_docker_compose = dep_method.get_file({ repo_dir: website.repo_dir, file: "docker-compose.yml"})
    expect_global_container(dep_method)
    prepare_ssh_session(dep_method.kill_global_container({ id: "cc2304677be0" }), "good")

    cmd_front_container = 
      dep_method.front_container({ website: website, website_location: website_location, in_port: 80 })
    prepare_ssh_session(cmd_front_container, "ok")
    expect_global_container(dep_method)
    prepare_ssh_session(dep_method.docker_compose({ front_container_id: "cc2304677be0" }), "ok")

    assert_scripted do
      begin_ssh
      dep_method.launch({ website: website, website_location: website_location })

      website.reload

      assert_equal website.container_id, "cc2304677be0"
    end
  end

  test "node_available?" do
    website = default_website
    website.container_id = "cc2304677be0"
    website.save
    dep_method = docker_compose_method

    prepare_ssh_session(dep_method.ps( { front_container_id: "cc2304677be0" }), 
      IO.read("test/fixtures/docker/docker-compose-ps.txt"))

    assert_scripted do
      begin_ssh
      result = dep_method.node_available?({ website: website })

      assert_equal result, true
    end
  end

  test "verify_instance_up" do
    website = default_website
    website.container_id = "cc2304677be0"
    website.save
    dep_method = docker_compose_method

    dep_method.verify_instance_up({ website: website, website_location: default_website_location })


    #prepare_ssh_session(dep_method.ps( { front_container_id: "cc2304677be0" }), 
    #  IO.read("test/fixtures/docker/docker-compose-ps.txt"))

    #assert_scripted do
    #  begin_ssh
    #  result = dep_method.verify_can_deploy({ website: website, website_location: default_website_location })

    #  assert_equal result, true
    #end
  end

  test "instance_up? with skip port check" do
    website = default_website
    website.configs ||= {}
    website.configs["SKIP_PORT_CHECK"] = true
    website.container_id = "cc2304677be0"
    website.save
    dep_method = docker_compose_method

    prepare_ssh_session(dep_method.ps( { front_container_id: "cc2304677be0" }), 
      IO.read("test/fixtures/docker/docker-compose-ps.txt"))

    assert_scripted do
      begin_ssh
      result = dep_method.instance_up?({ website: website, website_location: default_website_location })

      assert_equal result, true
    end
  end

  test "instance_up? with skip port check, but down containers" do
    website = default_website
    website.configs ||= {}
    website.configs["SKIP_PORT_CHECK"] = true
    website.container_id = "cc2304677be0"
    website.save
    dep_method = docker_compose_method

    prepare_ssh_session(dep_method.ps( { front_container_id: "cc2304677be0" }), 
      "down")

    assert_scripted do
      begin_ssh
      result = dep_method.instance_up?({ website: website, website_location: default_website_location })

      assert_equal result, false
    end
  end

  test "instance_up? without skip port check, instance up" do
    website = default_website
    website.container_id = "cc2304677be0"
    website.save
    dep_method = docker_compose_method

    prepare_ssh_session(dep_method.ps( { front_container_id: "cc2304677be0" }), 
      IO.read("test/fixtures/docker/docker-compose-ps.txt"))
    cmd_instance_up = dep_method.instance_up_cmd( { website_location: default_website_location })
    prepare_ssh_session(cmd_instance_up, "ok")

    assert_scripted do
      begin_ssh
      result = dep_method.instance_up?({ website: website, website_location: default_website_location })

      assert_equal result, true
    end
  end

  test "instance_up? without skip port check, instance down" do
    website = default_website
    website.container_id = "cc2304677be0"
    website.save
    dep_method = docker_compose_method

    prepare_ssh_session(dep_method.ps( { front_container_id: "cc2304677be0" }), 
      IO.read("test/fixtures/docker/docker-compose-ps.txt"))
    cmd_instance_up = dep_method.instance_up_cmd( { website_location: default_website_location })
    prepare_ssh_session(cmd_instance_up, "ok", 7)

    assert_scripted do
      begin_ssh
      result = dep_method.instance_up?({ website: website, website_location: default_website_location })

      assert_equal result, false
    end
  end

  test "verify_instance_up without skip port check, instance up" do
    website = default_website
    website.container_id = "cc2304677be0"
    website.valid = false
    website.save
    dep_method = docker_compose_method

    prepare_ssh_session(dep_method.ps( { front_container_id: "cc2304677be0" }), 
      IO.read("test/fixtures/docker/docker-compose-ps.txt"))
    cmd_instance_up = dep_method.instance_up_cmd( { website_location: default_website_location })
    prepare_ssh_session(cmd_instance_up, "ok")

    assert_scripted do
      begin_ssh
      dep_method.verify_instance_up({ website: website, website_location: default_website_location })

      website.reload

      assert_equal website.valid, true
    end
  end

  # TODO add finalize test
end
