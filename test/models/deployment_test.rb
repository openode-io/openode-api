require 'test_helper'

class DeploymentTest < ActiveSupport::TestCase
  test "Create properly with valid status" do
  	website = default_website
  	website_location = default_website_location
    dep = Deployment.new

    dep.status = "success"
    dep.website = website
    dep.website_location = website_location
    dep.result = {
    	what: {
    		is: 2
    	}
    }
    dep.save!
  end

  test "Create fails with invalid status" do
  	website = default_website
  	website_location = default_website_location
    dep = Deployment.new

    dep.status = "online2"
    dep.website = website
    dep.website_location = website_location
    dep.result = {
    	what: {
    		is: 2
    	}
    }

    begin
	    dep.save!
	    raise "invalid"
	rescue => ex
		assert_includes "#{ex}", "Validation failed"
	end
  end
end
