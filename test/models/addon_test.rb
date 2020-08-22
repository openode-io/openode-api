require 'test_helper'

class AddonTest < ActiveSupport::TestCase
  test "create valid addon" do
    addon = Addon.create(name: 'hello-world', category: 'what', obj: { this: 'is' })

    assert addon.valid?
  end

  test "simple name" do
    addon = Addon.create(name: 'hello', category: 'what')
    assert addon.valid?
  end

  test "name with number" do
    addon = Addon.create(name: 'hello-Asdf234', category: 'what')
    assert addon.valid?
    assert_equal addon.reload.name, 'hello-asdf234'
  end

  test "obj_field? - is present" do
    addon = Addon.create(name: 'hello-Asdf234', category: 'what', obj: { what: 123 })

    assert addon.reload.obj_field?('what')
  end

  test "obj_field? - not present" do
    addon = Addon.create(name: 'hello-Asdf234', category: 'what', obj: { what: 123 })

    assert_not addon.reload.obj_field?('what2')
  end
end
