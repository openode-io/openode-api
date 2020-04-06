require 'test_helper'

class WebsiteStatusTest < ActiveSupport::TestCase
  test 'create' do
    w = default_website

    web_status = WebsiteStatus.log(
      w,
      status: {
        what: 0,
        is: 1
      }
    )

    assert_equal web_status.website.id, w.id
    assert_equal web_status.obj['status']['what'], 0

    statuses = w.reload.statuses

    assert_equal statuses.length, 1
    assert_equal statuses.first.obj['status']['what'], 0
  end
end
