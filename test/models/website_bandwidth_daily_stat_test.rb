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

  test 'last_days - with within limits, and one outside' do
    w = default_website

    s1 = WebsiteBandwidthDailyStat.create(
      ref_id: w.id,
      obj: {
        'rcv_bytes' => 150,
        'tx_bytes' => 33
      },
      created_at: 1.days.ago
    )

    s2 = WebsiteBandwidthDailyStat.create(
      ref_id: w.id,
      obj: {
        'rcv_bytes' => 151,
        'tx_bytes' => 35
      },
      created_at: 25.days.ago
    )

    WebsiteBandwidthDailyStat.create(
      ref_id: w.id,
      obj: {
        'rcv_bytes' => 1000,
        'tx_bytes' => 100
      },
      created_at: 32.days.ago
    )

    stats = WebsiteBandwidthDailyStat.last_days(w)

    assert_equal stats.count, 2
    assert_includes stats, s1
    assert_includes stats, s2
  end

  test 'sum variable - happy path' do
    w = default_website

    WebsiteBandwidthDailyStat.create(
      ref_id: w.id,
      obj: {
        'rcv_bytes' => 150,
        'tx_bytes' => 33
      },
      created_at: 1.days.ago
    )

    WebsiteBandwidthDailyStat.create(
      ref_id: w.id,
      obj: {
        'rcv_bytes' => 151,
        'tx_bytes' => 35
      },
      created_at: 25.days.ago
    )

    WebsiteBandwidthDailyStat.create(
      ref_id: w.id,
      obj: {
        'rcv_bytes' => nil,
        'tx_bytes' => nil
      },
      created_at: 25.days.ago
    )

    stats = WebsiteBandwidthDailyStat.last_days(w)

    assert_equal WebsiteBandwidthDailyStat.sum_variable(stats, 'rcv_bytes'), 150+151
    assert_equal WebsiteBandwidthDailyStat.sum_variable(stats, 'tx_bytes'), 33+35
  end
end
