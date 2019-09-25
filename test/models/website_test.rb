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
        status: "starting",
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

    # repo dir
    test "repo dir" do
      w = Website.where(site_name: "testsite").first

      assert_equal w.repo_dir, "#{Website::REPOS_BASE_DIR}#{w.user_id}/#{w.site_name}/"
    end

    # storage area validation

    test "storage area validate with valid ones" do
      w = Website.where(site_name: "testsite").first
      w.storage_areas = ["tmp/", "what/is/this"]
      w.save!
      w.reload

      assert_equal w.storage_areas, ["tmp/", "what/is/this"]
    end

    test "storage area validate with invalid ones" do
      w = Website.where(site_name: "testsite").first
      w.storage_areas = ["../tmp/", "what/is/this"]
      w.save

      assert_equal w.valid?, false
    end

    # locations

    test "locations for a given website" do
      w = Website.where(site_name: "testsite").first

      assert_equal w.locations.length, 1
      assert_equal w.locations[0].str_id, "canada"
    end

    # normalize_storage_areas
    test "normalized_storage_areas with two areas" do
      w = Website.where(site_name: "testsite").first
      w.storage_areas = ["tmp/", "what/is/this/"]
      w.save
      w.reload

      n_storage_areas = w.normalized_storage_areas
      
      assert_equal n_storage_areas[0], "./tmp/"
      assert_equal n_storage_areas[1], "./what/is/this/"
    end

    # can_deploy_to?
    test "can_deploy_to? simple scenario should pass" do
      website = Website.find_by(site_name: "testsite")

      can_deploy, msg = website.can_deploy_to?(website.website_locations.first)
      assert_equal can_deploy, true
    end

    test "can_deploy_to? can't if user not activated" do
      website = Website.find_by(site_name: "testsite")
      website.user.activated = false
      website.user.save!
      website.user.reload

      can_deploy, msg = website.can_deploy_to?(website.website_locations.first)

      assert_equal can_deploy, false
      assert_includes msg, "not yet activated"
    end

    test "can_deploy_to? can't if user suspended" do
      website = Website.find_by(site_name: "testsite")
      website.user.suspended = true
      website.user.save!
      website.user.reload

      can_deploy, msg = website.can_deploy_to?(website.website_locations.first)

      assert_equal can_deploy, false
      assert_includes msg, "suspended"
    end
  end
end
