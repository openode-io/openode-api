
require 'test_helper'

class SystemStatTest < ActiveSupport::TestCase
  test 'Create properly website stat' do
    SystemStat.create!(obj: { nb_up: 4, nb_down: 2 })
    SystemStat.create!(obj: { nb_up: 5, nb_down: 2 })

    assert_equal SystemStat.count, 2
    assert_equal SystemStat.first.obj['nb_up'], 4
    assert_equal SystemStat.last.obj['nb_up'], 5
  end
end
