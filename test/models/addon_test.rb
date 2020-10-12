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

  test "requires_persistence? - when true" do
    obj = {
      this: 'is',
      requires_persistence: true,
      persistent_path: "/var/www",
      required_fields: %w[exposed_port persistent_path]
    }

    addon = Addon.create(name: 'hello-world', category: 'what', obj: obj)

    assert addon.valid?
    assert addon.requires_persistence?
  end

  test "requires_persistence? - when false" do
    obj = {
      this: 'is',
      requires_persistence: false
    }

    addon = Addon.create(name: 'hello-world', category: 'what', obj: obj)

    assert addon.valid?
    assert_not addon.requires_persistence?
  end

  test "requires_persistence? - when absent" do
    obj = {
      this: 'is'
    }

    addon = Addon.create(name: 'hello-world', category: 'what', obj: obj)

    assert addon.valid?
    assert_not addon.requires_persistence?
  end

  test "persistent path - fail if missing" do
    obj = {
      this: 'is',
      requires_persistence: true,
      required_fields: %w[exposed_port persistent_path]
    }

    addon = Addon.create(name: 'hello-world', category: 'what', obj: obj)

    assert_not addon.valid?
  end

  test "persistent path - fail if missing in required_fields" do
    obj = {
      this: 'is',
      requires_persistence: true,
      persistent_path: "/var/www",
      required_fields: ["exposed_port"]
    }

    addon = Addon.create(name: 'hello-world', category: 'what', obj: obj)

    assert_not addon.valid?
  end

  test "repository_url" do
    addon = Addon.create(name: 'hello-world', category: 'what', obj: { this: 'is' })

    assert_equal addon.repository_root_file_url, "https://raw.githubusercontent.com/openode-io/addons/master/what/hello-world"
  end
end
