require 'test_helper'

class WebsiteBandwidthDailyStatTest < ActiveSupport::TestCase
  test 'without daily stat' do
    website = default_website

    WebsiteBandwidthDailyStat.log(website, test: 10.0)

    last_stat = website.website_bandwidth_daily_stats.last
    assert_equal website.website_bandwidth_daily_stats.count, 1
    assert_equal last_stat.obj['test'], 10.0
  end

  test 'with existing daily stat' do
    website = default_website

    WebsiteBandwidthDailyStat.log(website, 'test' => 10.0)
    WebsiteBandwidthDailyStat.log(website, 'test' => 10.0)

    last_stat = website.website_bandwidth_daily_stats.last
    assert_equal website.website_bandwidth_daily_stats.count, 1
    assert_equal last_stat.obj['test'], 20.0
  end

  test 'with existing daily stat, muliple variables' do
    website = default_website

    WebsiteBandwidthDailyStat.log(website, 'test' => 10.0)
    WebsiteBandwidthDailyStat.log(website, 'test' => 10.0, 'test2' => 5.0)

    last_stat = website.website_bandwidth_daily_stats.last
    assert_equal website.website_bandwidth_daily_stats.count, 1
    assert_equal last_stat.obj['test'], 20.0
    assert_equal last_stat.obj['test2'], 5.0
  end
end
