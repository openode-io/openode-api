
require 'test_helper'

class CloudProviderHelpersPricingTest < ActiveSupport::TestCase
  test 'cost_for_extra_bandwidth_bytes full gb' do
    c = CloudProvider::Helpers::Pricing.cost_for_extra_bandwidth_bytes(1 * 1000 * 1000 * 1000)

    assert_equal c, CloudProvider::Helpers::Pricing::COST_EXTRA_BANDWIDTH_PER_GB
  end

  test 'cost_for_extra_bandwidth_bytes - few bytes' do
    c = CloudProvider::Helpers::Pricing.cost_for_extra_bandwidth_bytes(1000)

    expected = (1000.0 / (1000 * 1000 * 1000)) *
               CloudProvider::Helpers::Pricing::COST_EXTRA_BANDWIDTH_PER_GB
    assert_equal c, expected
  end
end
