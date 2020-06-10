require 'test_helper'

class LibTasksCreditsTest < ActiveSupport::TestCase
  setup do
    reset_emails
    set_all_offline
    WebsiteEvent.destroy_all
    Deployment.destroy_all
  end

  def set_all_offline
    Website.all.each do |w|
      w.status = Website::STATUS_OFFLINE
      w.save
    end
  end

  test "verify_expired_open_source - no online site" do
    invoke_task "credits:verify_expired_open_source"

    assert_equal WebsiteEvent.count, 0
  end

  test "verify_expired_open_source - one no deployment" do
    website = default_website
    website.status = Website::STATUS_ONLINE
    website.open_source_activated = true
    website.save!

    invoke_task "credits:verify_expired_open_source"

    # check that it has stop instance event
    last_event = website.reload.events.last

    assert_includes last_event.obj["title"], "Stopping instance"
  end
end
