
require 'test_helper'

module DeploymentMethod
  class GcloudRun < Base
    def ex(_cmd, _options = {})
      puts "exxxx"
    end
  end
end

class DeploymentMethodGcloudRunTest < ActiveSupport::TestCase
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first
  end

  def gcloud_run_method
    @runner ||= prepare_gcloud_run_runner(@website, @website_location)

    @runner.get_execution_method
  end

  test 'env variables string - happy path' do
    @website.overwrite_env_variables!({ TEST: "TOTO1", TEST2: "TOTO2" })
    result = gcloud_run_method.env_variables(@website)

    assert_equal result, "TEST=TOTO1,TEST2=TOTO2"
  end

  test 'env variables string - no variable' do
    @website.overwrite_env_variables!({})
    result = gcloud_run_method.env_variables(@website)

    assert_equal result, ""
  end

  # gcloud_cmd

  test 'gcloud_cmd - happy path' do
    result = gcloud_run_method.gcloud_cmd(
      website: @website, website_location: @website_location
    )

    assert_equal result, "timeout 400 sh -c 'cd #{@website.repo_dir} " \
      "&& gcloud --project openode '"
  end

  test 'gcloud_cmd - with custom timeout' do
    result = gcloud_run_method.gcloud_cmd(
      website: @website,
      website_location: @website_location,
      timeout: 10
    )

    assert_equal result, "timeout 10 sh -c 'cd #{@website.repo_dir} " \
      "&& gcloud --project openode '"
  end

  # image_tag_url

  test 'image_tag_url - happy path' do
    result = gcloud_run_method.image_tag_url(
      website: @website,
      website_location: @website_location
    )

    site_name = @website.site_name
    expected_url = "gcr.io/openode/#{site_name}:#{site_name}--#{@website.id}--" \
      "#{gcloud_run_method.runner.execution.id}"
    assert_equal result, expected_url
  end

  # build_image

  test 'build_image - happy path' do
    # result = gcloud_run_method.build_image(
    #  website: @website,
    #  website_location: @website_location,
    # )

    puts "test"
  end
end
