# frozen_string_literal: true

require 'test_helper'

class WebsiteBandwidthDailyStatTest < ActiveSupport::TestCase
  test 'without daily stat' do
    website = default_website

    WebsiteBandwidthDailyStat.log(website, test: 10.0)

    last_stat = website.website_bandwidth_daily_stats.last
    assert_equal website.website_bandwidth_daily_stats.count, 1
    assert_equal last_stat.obj['test'], 10.0
  end
end
