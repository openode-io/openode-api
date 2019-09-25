require 'test_helper'

class InternalTest < ActiveSupport::TestCase

	# calc_cost_per_month

	test "calc_cost_per_month 50 ram" do
		internal_provider = CloudProvider::Manager.instance.first_of_type("internal")

		assert_equal internal_provider.calc_cost_per_month(50).between?(0.40, 0.41), true
		assert_equal internal_provider.calc_cost_per_month(1024).between?(8.25, 8.27), true
		assert_equal internal_provider.calc_cost_per_month(2048).between?(16.51, 16.52), true
	end
end
