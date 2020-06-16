require 'test_helper'

class InstanceImageManagerTest < ActiveSupport::TestCase
  test 'instance - digital ocean' do
    instance = DeploymentMethod::Util::ImageRegistry.instance(
      "digital_ocean",
      registry_name: "openode-test"
    )

    assert_equal instance.opts, { registry_name: 'openode-test' }
  end
end
