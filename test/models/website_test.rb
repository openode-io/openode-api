require 'test_helper'

class WebsiteTest < ActiveSupport::TestCase

  class Validation < ActiveSupport::TestCase
    test "should not save required fields" do
      w = Website.new
      assert_not w.save
    end

    test "should save with all required fields" do
      w = Website.new({
        site_name: "thisisauniquesite",
        cloud_type: "cloud",
        user_id: User.first.id,
        type: "docker",
        domain_type: "subdomain"
        })

      assert w.save
    end

    test "get all custom domain websites" do
      custom_domain_sites = Website.custom_domain

      assert custom_domain_sites.length == 1
      assert custom_domain_sites[0].site_name == "www.what.is"
    end
  end

end
