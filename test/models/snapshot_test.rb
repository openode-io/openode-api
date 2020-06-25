require 'test_helper'

class SnapshotTest < ActiveSupport::TestCase
  test "creation happy path" do
    w = default_website
    w.snapshots.delete_all

    s = Snapshot.create!(website: w, path: '/my/')

    assert_equal s.status, Snapshot::STATUS_PENDING
    assert s.expire_at > Time.zone.now
    assert s.uid.length, 64
    assert_includes s.url, "snapshots.openode.io"
    assert_includes s.url, "/snapshots/#{s.uid}.zip"
    assert s.steps, []
  end

  test "snapshot invalid with empty path" do
    w = default_website
    w.snapshots.delete_all

    exception = assert_raises StandardError do
      Snapshot.create!(website: w, path: ' ')
    end

    assert_includes exception.inspect.to_s, "Path ensure to have a valid path"
  end

  test "creation fail if too recently snapshoted" do
    w = default_website

    exception = assert_raises StandardError do
      Snapshot.create!(website: w, path: '/my/')
    end

    assert_includes exception.inspect.to_s, "User limit reached"
  end

  test "with invalid path semicolon" do
    w = default_website

    s = Snapshot.new(website: w, path: '/m;y/')

    assert_equal s.valid?, false
  end

  test "with valid path with special chars" do
    w = default_website
    w.snapshots.delete_all

    s = Snapshot.new(website: w, path: '/m-w_whaty/')

    assert_equal s.valid?, true
  end

  test "with valid relative path" do
    w = default_website
    w.snapshots.delete_all

    s = Snapshot.new(website: w, path: 'what/is/that')

    assert_equal s.valid?, true
  end

  # get_destination_folder
  test "get_destination_folder happy path" do
    w = default_website

    s = Snapshot.create(website: w, path: 'what/is/that')

    assert_equal s.get_destination_folder,
                 "#{Snapshot::DEFAULT_DESTINATION_ROOT_PATH}#{s.uid}/"
  end

  test "get_destination_path happy path" do
    w = default_website

    s = Snapshot.create(website: w, path: 'what/is/that')

    assert_equal s.get_destination_path(".zip"),
                 "#{Snapshot::DEFAULT_DESTINATION_ROOT_PATH}#{s.uid}.zip"
  end
end
