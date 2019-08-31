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

    # domains:

    test "getting empty domains" do
      w = Website.where(site_name: "testsite").first
      w.domains ||= []
      w.save!
      w.reload

      assert w.domains.length == 0
    end

    test "getting domains" do
      w = Website.where(site_name: "www.what.is").first
      w.domains ||= []
      w.domains << "www.what.is"
      w.save!
      w.reload

      assert_equal w.domains.length, 1
      assert_equal w.domains[0], "www.what.is"
    end

    test "get all custom domain websites" do
      custom_domain_sites = Website.custom_domain

      assert custom_domain_sites.length == 1
      assert custom_domain_sites[0].site_name == "www.what.is"
    end

    test "getting configs" do
      w = Website.where(site_name: "testsite").first
      w.configs = { hello: "world", field2: 1234}
      w.save!
      w.reload

      assert_equal w.configs["hello"], "world"
      assert_equal w.configs["field2"], 1234
    end
  end

end
