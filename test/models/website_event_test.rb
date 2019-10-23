# frozen_string_literal: true

require 'test_helper'

class WebsiteEventTest < ActiveSupport::TestCase
  test 'Create properly valid website even' do
    website = Website.first

    e = WebsiteEvent.new
    e.ref_id = website.id
    e.type = 'WebsiteEvent'
    e.obj = { datatest: '1234' }
    e.save

    added_event = WebsiteEvent.last
    assert_equal added_event.website.id, website.id

    assert_equal website.events.count, 1
    assert_equal website.events.first.obj['datatest'], '1234'
  end
end
