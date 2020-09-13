
require 'test_helper'

class LibTasksUpdateAddonsTest < ActiveSupport::TestCase
  test "addons" do
    Addon.all.destroy_all
    invoke_task "update:addons"

    addon = Addon.last

    assert_equal addon.name, 'redis-caching'
    assert_equal addon.category, 'caching'
    assert_equal addon.obj.dig('name'), 'redis-caching'
    assert_equal addon.obj.dig('documentation_filename'), 'README.md'
  end
end
