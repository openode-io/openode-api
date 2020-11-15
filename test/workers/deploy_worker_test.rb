
require 'test_helper'

class DeployWorkerTest < ActiveSupport::TestCase
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first
    kubernetes_method
  end

  def kubernetes_method
    @runner ||= prepare_kubernetes_runner(@website, @website_location)

    @runner.get_execution_method
  end

  test "prepare_execution with repository_url" do
    repo = "git@github.com:openode-io/openode-api.git"
    params = { "repository_url" => repo }
    DeployWorker.prepare_execution(@runner, 'Deployment', params)
    
    assert_equal @website.reload.secret[:repository_url], repo
  end
end

