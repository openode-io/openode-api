
require 'test_helper'

class LibTasksVerifyWebsiteEnvironmentTest < ActiveSupport::TestCase
  test "open_source_activated - with one to deactivate" do
    w = default_website
    w.open_source = {
      'status' => '',
      'title' => '',
      'description' => 'a ' * 31,
      'repository_url' => 'http://github.com/myrepo'
    }

    w.open_source_activated = true
    w.status = Website::STATUS_ONLINE
    w.save(validate: false)

    invoke_task "verify_website_environment:open_source_activated"

    w.reload

    assert_equal w.open_source_activated, false
  end

  test "open_source_activated - site valid should not deactivate" do
    w = default_website
    w.open_source = {
      'status' => 'approved',
      'title' => 'hello world',
      'description' => 'a ' * 31,
      'repository_url' => 'http://github.com/myrepo'
    }

    w.open_source_activated = true
    w.status = Website::STATUS_ONLINE
    w.save(validate: false)

    invoke_task "verify_website_environment:open_source_activated"

    w.reload

    assert_equal w.open_source_activated, true
  end
end
