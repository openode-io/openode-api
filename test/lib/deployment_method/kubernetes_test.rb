
require 'test_helper'

class DeploymentMethodKubernetesTest < ActiveSupport::TestCase
  def setup; end

  def kubernetes_method(website = default_kube_website,
                        website_location = default_website_location)
    configs = {}
    configs[:website] = website
    configs[:website_location] = website_location

    runner = DeploymentMethod::Runner.new(Website::TYPE_KUBERNETES, 'cloud', configs)
    runner.get_execution_method
  end

  test 'verify_can_deploy - can do it' do
    website = default_kube_website
    website_location = website.website_locations.first
    dep_method = kubernetes_method(website, website_location)

    dep_method.verify_can_deploy(website: website, website_location: website_location)
  end

  test 'verify_can_deploy - lacking credits' do
    website = default_kube_website
    website_location = website.website_locations.first
    dep_method = kubernetes_method(website, website_location)
    user = website.user
    user.credits = 0
    user.save!

    assert_raises StandardError do
      dep_method.verify_can_deploy(website: website, website_location: website_location)
    end
  end
end
