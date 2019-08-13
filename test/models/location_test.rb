require 'test_helper'

class LocationTest < ActiveSupport::TestCase
  test "retrieve canada" do
     assert Location.find_by! str_id: "canada"
  end
end
