# frozen_string_literal: true

require 'test_helper'

class DeploymentTest < ActiveSupport::TestCase
  test 'Create properly with valid status' do
    website = default_website
    website_location = default_website_location
    dep = Deployment.new

    dep.status = 'success'
    dep.website = website
    dep.website_location = website_location
    dep.result = {
      what: {
        is: 2
      }
    }
    dep.save!
  end

  test 'default status should be running' do
    website = default_website
    website_location = default_website_location
    dep = Deployment.create!(
      website: website,
      website_location: website_location,
      status: Deployment::STATUS_RUNNING
    )

    assert_equal dep.status, Deployment::STATUS_RUNNING
    assert_equal dep.result['steps'], []
    assert_equal dep.result['errors'], []
  end

  test 'Create fails with invalid status' do
    website = default_website
    website_location = default_website_location
    dep = Deployment.new

    dep.status = 'online2'
    dep.website = website
    dep.website_location = website_location
    dep.result = {
      what: {
        is: 2
      }
    }

    begin
     dep.save!
     raise 'invalid'
    rescue StandardError => e
      assert_includes e.to_s, 'Validation failed'
   end
  end

  test 'humanize_events with events' do
    website = default_website
    website_location = default_website_location
    dep = Deployment.new

    dep.status = 'success'
    dep.website = website
    dep.website_location = website_location
    dep.result = {
      what: {
        is: 2
      }
    }
    dep.events = [
      { "status": "running", "level": "info", "update": "Verifying allowed to deploy..." },
      { "status": "running", "level": "info", "update": "Preparing instance image..." }
    ]
    dep.save!

    result = dep.humanize_events

    assert_includes result, dep.events[0]['update']
    assert_includes result, dep.events[1]['update']
  end

  test 'humanize_events without events' do
    website = default_website
    website_location = default_website_location
    dep = Deployment.new

    dep.status = 'success'
    dep.website = website
    dep.website_location = website_location
    dep.result = {
      what: {
        is: 2
      }
    }
    dep.events = nil
    dep.save!

    result = dep.humanize_events

    assert_equal result, ""
  end

  test 'nb_archived_deployments - with archived' do
    GlobalStat.increase!("nb_archived_deployments", 1)
    GlobalStat.increase!("nb_archived_deployments", 1)

    assert_equal Deployment.nb_archived_deployments, 2
  end

  test 'nb_archived_deployments - without archived' do
    assert_equal Deployment.nb_archived_deployments, 0
  end

  test 'total_nb - without archived' do
    assert_equal Deployment.total_nb, 4
  end

  test 'total_nb - with archived' do
    GlobalStat.increase!("nb_archived_deployments", 1)
    assert_equal Deployment.total_nb, 5
  end
end
