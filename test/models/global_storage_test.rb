require 'test_helper'

class GlobalStorageTest < ActiveSupport::TestCase
  test "creates properly" do
    GlobalStorage.create!(obj: { 'hi' => 'world' })

    instance = GlobalStorage.last!
    assert_equal instance.obj['hi'], 'world'
  end
end
