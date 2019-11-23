require 'test_helper'

class CollaboratorTest < ActiveSupport::TestCase
  test "resolve associations" do
    c = Collaborator.first

    assert_equal c.user.email, "myadmin2@thisisit.com"
    assert_equal c.website.site_name, "testsite2"
  end

  # validation
  test "must have at least one permission" do
    c = Collaborator.first
    c.permissions = []
    c.save

    assert_equal c.valid?, false
    assert_includes c.errors.inspect.to_s, "must have at least one"
  end

  test "when root permission, should only contain one permission" do
    c = Collaborator.first
    c.permissions = [Collaborator::PERMISSION_ROOT, Collaborator::PERMISSION_PLAN]
    c.save

    assert_equal c.valid?, false
    assert_includes c.errors.inspect.to_s, "when root permission"
  end

  test "a collaborator should not be the website owner" do
    Collaborator.all.destroy_all

    website = default_website
    c = Collaborator.create(
      website: website,
      user: website.user,
      permissions: [Collaborator::PERMISSION_ROOT]
    )

    assert_equal c.valid?, false
  end
end
