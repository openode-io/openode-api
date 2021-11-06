
require 'test_helper'

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
    @website.overwrite_env_variables!({TEST: "TOTO1", TEST2: "TOTO2"})
    result = gcloud_run_method.env_variables(@website)

    assert_equal result, "TEST=TOTO1,TEST2=TOTO2"
  end

  test 'env variables string - no variable' do
    @website.overwrite_env_variables!({})
    result = gcloud_run_method.env_variables(@website)

    assert_equal result, ""
  end
end