
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

    # one click app should be removed if it's not using direct template
    @website.one_click_app = { "version" => "latest" }
    @website.save!

    DeployWorker.prepare_execution(@runner, 'Deployment', params)

    assert_equal @website.reload.secret[:repository_url], repo
    assert_equal @website.one_click_app, {}
  end

  test "prepare_execution with repository_url with template" do
    repo = "git@github.com:openode-io/openode-api.git"
    params = { "repository_url" => repo, "template" => "nodered" }
    app = OneClickApp.find_by(name: "nodered")

    # one click app should be removed if it's not using direct template
    @website.one_click_app = { "version" => "latest" }
    @website.save!

    DeployWorker.prepare_execution(@runner, 'Deployment', params)

    assert_equal @website.reload.secret[:repository_url], repo
    assert_equal @website.one_click_app, { "version" => "latest", "id" => app.id }
  end
end
