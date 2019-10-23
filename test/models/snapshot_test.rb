# frozen_string_literal: true

require 'test_helper'

class SnapshotTest < ActiveSupport::TestCase
  test 'relation with website' do
    website = Website.find_by site_name: 'testsite'
    assert_equal website.snapshots.length, 1
  end
end
