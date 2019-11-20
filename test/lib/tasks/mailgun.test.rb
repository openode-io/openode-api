
require 'test_helper'

class LibTasksMailgunTest < ActiveSupport::TestCase
  test "should remove newsletter if failed email" do
    u1 = User.first
    u1.email = "xhanolivia@gakkurang.com"
    u1.newsletter = false
    u1.save!

    u2 = User.last
    u2.email = "aafdssadf@sdf.com"
    u2.newsletter = true
    u2.save!

    invoke_task "mailgun:check_failed_events"

    u1.reload
    u2.reload

    assert_equal u1.newsletter?, false
    assert_equal u2.newsletter?, false
  end
end
