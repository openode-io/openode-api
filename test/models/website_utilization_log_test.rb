require 'test_helper'

class WebsiteUtilizationLogTest < ActiveSupport::TestCase
  test 'log' do
    website = default_website

    WebsiteUtilizationLog.log(website, test: 10.0)

    last_stat = website.website_utilization_logs.last
    assert_equal website.website_utilization_logs.count, 1
    assert_equal last_stat.obj['test'], 10.0
  end
end
