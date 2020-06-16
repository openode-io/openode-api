require 'test_helper'

class LibTasksRegistryTest < ActiveSupport::TestCase
  test "clean - happy path" do
    invoke_task "registry:clean"
  end
end
