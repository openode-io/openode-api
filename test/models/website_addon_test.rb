require 'test_helper'

class WebsiteAddonTest < ActiveSupport::TestCase
  test "create - happy path" do
    w = default_website
    addon = Addon.first

    wa = WebsiteAddon.create!(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    assert wa.valid?
    assert wa.storage_gb.zero?
  end

  test "create - website with two addons with the same name is invalid" do
    w = default_website
    addon = Addon.first

    WebsiteAddon.create!(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    assert_raises StandardError do
      WebsiteAddon.create(
        name: 'hi-world',
        account_type: 'second',
        website: w,
        addon: addon,
        obj: {
          attrib: 'val1'
        }
      )
    end
  end

  test "create - 2 websites with 2 addons with the same name are valid" do
    w = Website.first
    w2 = Website.last
    addon = Addon.first

    WebsiteAddon.create!(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    wa = WebsiteAddon.create(
      name: 'hi-world',
      account_type: 'second',
      website: w2,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    assert wa.valid?
  end

  test "required fields should be specified" do
    w = Website.first
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['required_fields'] = %w[exposed_port what]
    addon.save!

    WebsiteAddon.create!(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1',
        exposed_port: 4455,
        what: 'yes!'
      }
    )
  end

  test "required fields - missing one" do
    w = Website.first
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['required_fields'] = %w[exposed_port what]
    addon.save!

    wa = WebsiteAddon.create(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1',
        exposed_port: 4455
      }
    )

    assert_equal wa.valid?, false
  end

  test "create - with valid minimum plan" do
    w = default_website
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['minimum_memory_mb'] = 100
    addon.obj['requires_persistence'] = true
    addon.obj['persistent_path'] = "/var/www"
    addon.obj['required_fields'] = ['persistent_path']
    addon.save!

    wa = WebsiteAddon.create(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      },
      storage_gb: 1
    )

    assert wa.valid?

    # defaults persistent path to the one from addon
    assert wa.obj['persistent_path'] == "/var/www"

    wa.obj['persistent_path'] = "/var2/www"
    wa.save!
    wa.reload
    assert wa.obj['persistent_path'] == "/var2/www"

    # verify wa.persistence?
    assert wa.persistence?
  end

  test "create - defaulting env variables" do
    w = default_website
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['minimum_memory_mb'] = 100
    addon.obj['required_env_variables'] = %w[TITI TOTO]
    addon.obj['env_variables'] = {
      "TITI": "asdf",
      "TOTO": 1234
    }
    addon.save!

    wa = WebsiteAddon.create!(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    assert_equal wa.obj.dig('env', 'TITI'), "asdf"
    assert_equal wa.obj.dig('env', 'TOTO'), 1234
  end

  test "create - with too high storage gb" do
    w = default_website
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['minimum_memory_mb'] = 100
    addon.obj['requires_persistence'] = true
    addon.obj['persistent_path'] = "/var/www"
    addon.obj['required_fields'] = ['persistent_path']
    addon.save!

    wa = WebsiteAddon.create!(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    wa.storage_gb = 100
    wa.save

    assert_not wa.valid?
  end

  test "create - with too low storage gb" do
    w = default_website
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['minimum_memory_mb'] = 100
    addon.obj['requires_persistence'] = true
    addon.obj['persistent_path'] = "/var/www"
    addon.obj['required_fields'] = ['persistent_path']
    addon.save!

    wa = WebsiteAddon.create!(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    wa.storage_gb = 0
    wa.save

    assert_not wa.valid?
  end

  test "update requires all required env variables" do
    w = default_website
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['minimum_memory_mb'] = 100
    addon.obj['required_env_variables'] = %w[TITI TOTO]
    addon.save!

    wa = WebsiteAddon.create!(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    wa.obj['env'] = {
      "TOTO": 11
    }

    assert_not wa.valid?

    # now with all required env vars
    wa.obj['env'] = {
      "TOTO" => 11,
      "TITI" => "1122"
    }

    wa.save!
    assert wa.valid?
  end

  test "create - can't use open source plan" do
    w = default_website
    addon = Addon.first

    wa = WebsiteAddon.create(
      name: 'hi-world',
      account_type: Website::OPEN_SOURCE_ACCOUNT_TYPE,
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    assert_equal wa.valid?, false
  end

  test "create - can't use with website open source plan" do
    w = default_website
    w.account_type = Website::OPEN_SOURCE_ACCOUNT_TYPE
    w.open_source = {
      'status' => 'approved',
      'title' => 'helloworld',
      'description' => 'a ' * 31,
      'repository_url' => 'http://github.com/myrepo'
    }
    w.save!
    addon = Addon.first

    wa = WebsiteAddon.create(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    assert_equal wa.valid?, false
  end

  test "create - with too small plan" do
    w = default_website
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['minimum_memory_mb'] = 500
    addon.save!

    wa = WebsiteAddon.create(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1'
      }
    )

    assert_equal wa.valid?, false
  end

  test "create - with valid required env variables" do
    w = default_website
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['required_env_variables'] = %w[PORT HOST]
    addon.save!

    wa = WebsiteAddon.create(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1',
        env: {
          PORT: 4455,
          HOST: 'localhost'
        }
      }
    )

    assert wa.valid?
  end

  test "create - with missing required env variables" do
    w = default_website
    addon = Addon.first
    addon.obj ||= {}
    addon.obj['required_env_variables'] = %w[PORT HOST]
    addon.save!

    wa = WebsiteAddon.create(
      name: 'hi-world',
      account_type: 'second',
      website: w,
      addon: addon,
      obj: {
        attrib: 'val1',
        env: {
          PORT: 4455
        }
      }
    )

    assert_equal wa.valid?, false
  end
end
