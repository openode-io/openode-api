require 'test_helper'

class CollaboratorTest < ActiveSupport::TestCase
  test "resolve associations" do
    c = Collaborator.first
    
    assert_equal c.user.email, "myadmin2@thisisit.com"
    assert_equal c.website.site_name, "testsite2"
  end
end
