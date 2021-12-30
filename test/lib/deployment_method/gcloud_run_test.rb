
require 'test_helper'
# require 'test_gcloud_run_helper'

class DeploymentMethodGcloudRunTest < ActiveSupport::TestCase
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first
  end

  def gcloud_run_method
    @runner ||= prepare_gcloud_run_runner(@website, @website_location)

    gcloud_test = DeploymentMethod::GcloudRunTest.new

    @runner.set_execution_method(gcloud_test)

    gcloud_test
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

  # region_of

  test 'region_of - happy path' do
    result = gcloud_run_method.region_of(@website_location)

    assert_equal result, "kubecan"
  end

  # gcloud_cmd

  test 'gcloud_cmd - happy path' do
    result = gcloud_run_method.gcloud_cmd(
      website: @website, website_location: @website_location
    )

    assert_equal result, "timeout 400 sh -c 'cd #{@website.repo_dir} " \
      "&& gcloud --project openode '"
  end

  test 'gcloud_cmd - without chg_dir_workspace' do
    result = gcloud_run_method.gcloud_cmd(
      website: @website,
      website_location: @website_location,
      chg_dir_workspace: false
    )

    assert_equal result, "timeout 400 sh -c 'gcloud --project openode '"
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
    run_method = gcloud_run_method
    run_method.ex_return = [
      {

      },
      {
        stderr: "Created [https://cloudbuild.googleapis.com/build-id-1234567]",
        exit_code: 0
      },
      {
        exit_code: 0,
        stdout: "output"
      }
    ]
    result = run_method.build_image(
      website: @website,
      website_location: @website_location
    )

    site_name = @website.site_name
    exec_id = @runner.execution.id

    expected_result = "gcr.io/openode/#{site_name}:#{site_name}--#{@website.id}--#{exec_id}"
    assert_equal result, expected_result
  end

  # launch

  test 'launch - happy path' do
    run_method = gcloud_run_method
    run_method.ex_return = [
      {
        exit_code: 0
      },
      {
        stderr: "Created [https://cloudbuild.googleapis.com/build-id-1234567]",
        exit_code: 0
      },
      {
        exit_code: 0,
        stdout: "output"
      },
      {
        exit_code: 0
      },
      {
        stdout: "[{\"status\": {\"url\": \"https://serviceurl\"}}]",
        exit_code: 0
      }
    ]
    run_method.ex_stdout_return = [
      "output_logs"
    ]

    result = run_method.launch(
      website: @website,
      website_location: @website_location
    )

    assert_equal result, true
    assert_equal run_method.ex_history.count, 5
    assert_equal run_method.ex_stdout_history.count, 1

    assert_equal @website_location.obj["gcloud_url"], "https://serviceurl"
  end

  # status_cmd

  test 'status_cmd - happy path' do
    result = gcloud_run_method.status_cmd(
      website: @website,
      website_location: @website_location
    )

    assert_includes result, "run services describe instance-#{@website.id}"
  end

  # retrieve_logs_gcloud_run_cmd

  test 'retrieve_logs_gcloud_run_cmd - happy path' do
    result = gcloud_run_method.retrieve_logs_gcloud_run_cmd(
      website: @website,
      website_location: @website_location,
      nb_lines: 10
    )

    assert_includes result, "instance-#{@website.id}"
    assert_includes result, "logs --tail 10"
  end
end
