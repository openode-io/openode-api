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
    WebsiteBandwidthDailyStat.log(website, 'test' => 10.0, 'test2' => 5.0,
                                           'old_stuff' => { asdf: 234 })
    WebsiteBandwidthDailyStat.log(website, 'old_stuff' => { asdf: 2345 })

    last_stat = website.website_bandwidth_daily_stats.last
    assert_equal website.website_bandwidth_daily_stats.count, 1
    assert_equal last_stat.obj['test'], 30.0
    assert_equal last_stat.obj['test2'], 10.0
    assert_equal last_stat.obj['old_stuff']['asdf'], 2345
  end
end
