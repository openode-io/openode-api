# frozen_string_literal: true

require 'test_helper'

class DeploymentMethodBaseTest < ActiveSupport::TestCase
  def setup
    @base_dep_method = DeploymentMethod::Base.new
  end

  test 'mark accessed' do
    website = Website.find_by site_name: 'testsite'
    base_dep_method = DeploymentMethod::Base.new

    website.last_access_at = Time.zone.now
    website.save!

    base_dep_method.mark_accessed(website: website)
    website.reload

    assert_equal Time.zone.now - website.last_access_at <= 5, true
  end

  test 'initialization' do
    website = Website.find_by site_name: 'testsite'

    website.last_access_at = Time.zone.now
    website.save!
    website.change_status!(Website::STATUS_OFFLINE)
    website_location = website.website_locations.first

    @base_dep_method.initialization(website: website, website_location: website_location)
    website.reload

    assert_equal Time.zone.now - website.last_access_at <= 5, true
    assert_equal website.status, Website::STATUS_STARTING
  end

  test 'clear_repository' do
    cmd = @base_dep_method.clear_repository(website: default_website)

    assert_equal cmd, "rm -rf #{default_website.repo_dir}"
  end

  test 'verify_can_deploy without failure' do
    website = default_website
    website_location = website.website_locations.first

    @base_dep_method.verify_can_deploy(website: website, website_location: website_location)
  end

  test 'verify_can_deploy with failure' do
    website = default_website
    website_location = website.website_locations.first

    website.user.activated = false

    user = website.user
    user.email = "myinvalidemail@gmail.com"
    user.save!

    website.user.save

    begin
      @base_dep_method.verify_can_deploy(website: website, website_location: website_location)
      assert_equal true, false
    rescue StandardError => e
      assert_equal e.class, ApplicationRecord::ValidationError
    end
  end

  test 'finalize when success, nothing running' do
    website = default_website
    website_location = default_website_location

    website.status = Website::STATUS_ONLINE
    website.save!
    website_location.port = 11_500
    website_location.second_port = 11_501
    website_location.running_port = nil
    website_location.save

    @base_dep_method.finalize(website: website, website_location: website_location)

    website_location.reload
    website.reload

    assert_equal website_location.running_port, 11_500
    assert_equal website.status, Website::STATUS_ONLINE
  end

  test 'finalize when success, one existing running' do
    website = default_website
    website_location = default_website_location

    website.status = Website::STATUS_ONLINE
    website.save!
    website_location.port = 11_500
    website_location.second_port = 11_501
    website_location.running_port = 11_500
    website_location.save

    @base_dep_method.finalize(website: website, website_location: website_location)

    website_location.reload
    website.reload

    assert_equal website_location.running_port, 11_501
    assert_equal website.status, Website::STATUS_ONLINE
  end

  test 'finalize when failure, nothing running' do
    website = default_website
    website_location = default_website_location

    website.status = Website::STATUS_STARTING
    website.save!
    website_location.port = 11_500
    website_location.second_port = 11_501
    website_location.running_port = nil
    website_location.save!

    @base_dep_method.finalize(website: website, website_location: website_location)

    website_location.reload
    website.reload

    assert_equal website_location.running_port, nil
    assert_equal website.status, Website::STATUS_OFFLINE
  end

  # final_instance_details

  test 'final_instance_details with subdomain' do
    website = default_website
    website_location = default_website_location

    result = @base_dep_method.final_instance_details(website: website,
                                                     website_location: website_location)

    assert_equal result['result'], 'success'
    assert_equal result['url'], 'http://testsite.openode.io/'
  end

  test 'final_instance_details with custom domain' do
    website = Website.find_by! site_name: 'www.what.is'
    website_location = website.website_locations.first

    result = @base_dep_method.final_instance_details(website: website,
                                                     website_location: website_location)

    assert_equal result['result'], 'success'
    assert_equal result['url'], 'http://www.what.is/'
    assert_equal result['NS Records (Nameservers)'], ['ns1.vultr.com', 'ns2.vultr.com']
    assert_equal result['A Record'], '127.0.0.2'
  end

  test 'erase_repository_files' do
    cmd = @base_dep_method.erase_repository_files(path: "/home/1234/what/")

    assert_equal cmd, "rm -rf /home/1234/what/"
  end

  test 'ensure_remote_repository' do
    cmd = @base_dep_method.ensure_remote_repository(path: "/home/1234/what/")

    assert_equal cmd, "mkdir -p /home/1234/what/"
  end

  test 'begin_stop - happy path' do
    website = default_website
    website.change_status!(Website::STATUS_OFFLINE)

    @base_dep_method.begin_stop website

    assert website.reload.stopping?
  end

  test 'begin_stop - multiple times should fail' do
    website = default_website
    website.change_status!(Website::STATUS_OFFLINE)

    @base_dep_method.begin_stop website

    assert_raises StandardError do
      @base_dep_method.stop(website: website, website_location: website.website_locations.first)
    end

    assert website.reload.stopping?
  end

  test 'notify_or_soft_log - with notification + exception' do
    assert_raises StandardError do
      @base_dep_method.notify_or_soft_log("hello", false)
    end
  end

  test 'notify_or_soft_log - without notification + exception' do
    @base_dep_method.notify_or_soft_log("hello", true)
  end
end
