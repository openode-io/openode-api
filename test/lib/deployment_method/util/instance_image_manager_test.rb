require 'test_helper'

class InstanceImageManagerTest < ActiveSupport::TestCase
  def setup
    @website = default_website
    @deployment = @website.deployments.last
    cloud_provider_manager = CloudProvider::Manager.instance
    build_server = cloud_provider_manager.docker_build_server
    img_location = cloud_provider_manager.docker_images_location

    configs = {
      website: @website,
      website_location: @website.website_locations.first,
      host: build_server['ip'],
      secret: {
        user: build_server['user'],
        private_key: build_server['private_key']
      }
    }

    runner = DeploymentMethod::Runner.new(Website::TYPE_KUBERNETES, 'cloud', configs)

    @manager = DeploymentMethod::Util::InstanceImageManager.new(
      runner: runner,
      docker_images_location: img_location,
      website: @website,
      deployment: @deployment
    )

    runner.set_execution_method(@manager)

    @timeout_part = "timeout " \
                    "#{DeploymentMethod::Util::InstanceImageManager::MAX_BUILD_TIMEOUT}s "
  end

  test 'verify image size cmd' do
    project_path = '/home/123456/what'

    cmd = @manager.verify_size_repo_cmd(
      project_path: project_path
    )

    assert_equal cmd, "du -bs #{project_path}"
  end

  test 'verify_size_repo with small repository' do
    project_path = '/home/123456/what'

    expected_cmd = @manager.verify_size_repo_cmd(
      project_path: "/home/#{@website.user_id}/#{@website.site_name}/"
    )
    prepare_ssh_session(expected_cmd, "61595  #{project_path}")

    assert_scripted do
      begin_ssh

      @manager.verify_size_repo
    end
  end

  test 'verify_size_repo with too large repository' do
    project_path = '/home/123456/what'

    expected_cmd = @manager.verify_size_repo_cmd(
      project_path: "/home/#{@website.user_id}/#{@website.site_name}/"
    )

    size = DeploymentMethod::Util::InstanceImageManager::LIMIT_REPOSITORY_BYTES
    prepare_ssh_session(expected_cmd, "#{size * 2}  #{project_path}")

    assert_scripted do
      begin_ssh

      assert_raises StandardError do
        @manager.verify_size_repo
      end
    end
  end

  test 'ensure_no_execution_error without error' do
    obj = { result: { exit_code: 0 } }
    @manager.ensure_no_execution_error("step name..", obj)
  end

  test 'ensure_no_execution_error with non exit zero' do
    obj = {
      result: {
        exit_code: 1,
        stdout: 'stdout msg',
        stderr: 'stderr msg'
      }
    }

    exception = assert_raises StandardError do
      @manager.ensure_no_execution_error("step name..", obj)
    end

    assert_includes exception.inspect.to_s, "stdout msg"
    assert_includes exception.inspect.to_s, "stderr msg"
    assert_not_includes exception.inspect.to_s, "Docker timeout reached"
  end

  test 'ensure_no_execution_error with non exit zero, with diagnostic' do
    obj = {
      result: {
        exit_code: 1,
        stdout: 'stdout msg',
        stderr: 'stderr msg You need to install the latest version of Python'
      }
    }

    exception = assert_raises StandardError do
      @manager.ensure_no_execution_error("step name..", obj)
    end

    assert_includes exception.inspect.to_s, "stdout msg"
    assert_includes exception.inspect.to_s, "stderr msg"
    assert_includes exception.inspect.to_s, "Python package is missing"
  end

  test 'ensure_no_execution_error with exit timeout' do
    obj = {
      result: {
        exit_code: DeploymentMethod::Util::InstanceImageManager::TIMEOUT_EXIT_CODE,
        stdout: 'stdout msg',
        stderr: 'stderr msg'
      }
    }

    exception = assert_raises StandardError do
      @manager.ensure_no_execution_error("step name..", obj)
    end

    assert_includes exception.inspect.to_s, "stdout msg"
    assert_includes exception.inspect.to_s, "stderr msg"
    assert_includes exception.inspect.to_s, "Docker timeout reached"
  end

  test 'build cmd' do
    cmd = @manager.build_cmd(
      project_path: '/home/123456/what'
    )

    assert_includes cmd, 'cd /home/123456/what'

    build_cmd = "sudo #{@timeout_part}docker build -t docker.io/openode_prod/#{@website.site_name}:"

    assert_includes cmd, "#{build_cmd}" \
                          "#{@website.site_name}--#{@website.id}--#{@deployment.id} ."
  end

  test 'build' do
    expected_cmd = "cd /home/#{@website.user.id}/#{@website.site_name}/ && " \
      "sudo #{@timeout_part}docker build " \
      "-t docker.io/openode_prod/#{@website.site_name}" \
      ":#{@website.site_name}--#{@website.id}--#{@deployment.id} ."
    prepare_ssh_session(expected_cmd, 'successfully built')

    assert_scripted do
      begin_ssh

      result = @manager.build

      assert_equal result.length, 1
      assert_equal result[0][:cmd_name], "build_cmd"
      assert_equal result[0][:result][:stdout], "successfully built"
    end
  end

  test 'push' do
    expected_cmd = "echo t123456 | sudo docker login -u test docker.io --password-stdin && " \
      "sudo docker push docker.io/openode_prod/#{@website.site_name}" \
      ":#{@website.site_name}--#{@website.id}--#{@deployment.id}"
    prepare_ssh_session(expected_cmd, 'successfully pushed')

    assert_scripted do
      begin_ssh

      result = @manager.push

      assert_equal result.length, 1
      assert_equal result[0][:cmd_name], "push_cmd"
      assert_equal result[0][:result][:stdout], "successfully pushed"
    end
  end

  test 'push when failing' do
    expected_cmd = "echo t123456 | sudo docker login -u test docker.io --password-stdin && " \
      "sudo docker push docker.io/openode_prod/#{@website.site_name}" \
      ":#{@website.site_name}--#{@website.id}--#{@deployment.id}"

    prepare_ssh_session(expected_cmd, 'failed to push', 1)
    prepare_ssh_session(expected_cmd, 'failed to push', 2)
    prepare_ssh_session(expected_cmd, 'failed to push', 3)

    assert_scripted do
      begin_ssh

      @manager.push

    rescue StandardError => e
      assert_includes e.to_s, "Failed at pushing the image"
      assert_includes e.to_s, "exit code = 3"
    end
  end
end
