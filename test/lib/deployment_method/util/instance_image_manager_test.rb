require 'test_helper'

class InstanceImageManagerTest < ActiveSupport::TestCase
  def setup
    @website = default_website
    @deployment = @website.deployments.last
    cloud_provider_manager = CloudProvider::Manager.instance
    build_server = cloud_provider_manager.docker_build_server
    img_location = cloud_provider_manager.docker_images_location

    @manager = DeploymentMethod::Util::InstanceImageManager.new(
      docker_build_server: build_server,
      docker_images_location: img_location,
      website: @website,
      website_location: @website.website_locations.first,
      deployment: @deployment
    )
  end

  test 'build cmd' do
    repo = 'openode/op_prod'

    cmd = @manager.build_cmd(
      project_path: '/home/123456/what',
      repository_name: repo
    )

    assert_includes cmd, 'cd /home/123456/what'
    assert_includes cmd, "docker build -t #{repo}:#{@website.site_name}" \
                          "--#{@website.id}--#{@deployment.id} ."
  end

  test 'build' do
    expected_cmd = "cd /home/#{@website.user.id}/#{@website.site_name}/ && " \
      "docker build " \
      "-t test/openode_prod:#{@website.site_name}--#{@website.id}--#{@deployment.id} ."
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
    expected_cmd = "echo t123456 | docker login -u test --password-stdin && " \
      "docker push test/openode_prod:#{@website.site_name}--#{@website.id}--#{@deployment.id}"
    prepare_ssh_session(expected_cmd, 'successfully pushed')

    assert_scripted do
      begin_ssh

      result = @manager.push

      assert_equal result.length, 1
      assert_equal result[0][:cmd_name], "push_cmd"
      assert_equal result[0][:result][:stdout], "successfully pushed"
    end
  end
end
