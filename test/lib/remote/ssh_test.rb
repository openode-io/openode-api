# https://net-ssh.github.io/ssh/v2/api/classes/Net/SSH/Test.html

require 'test_helper'

class RemoteSshTest < ActiveSupport::TestCase

  def setup

  end

  test "single basic command" do
    prepare_ssh_session("ls", "root what")

    assert_scripted do
      begin_ssh
      result = Remote::Ssh.exec(["ls"], {})

      assert_equal result[0][:stdout], "root what"
    end
  end

  test "multiple commands" do
    prepare_ssh_session("ls", "root what")
    prepare_ssh_session("cat toto", "big content")

    assert_scripted do
      begin_ssh
      result = Remote::Ssh.exec(["ls", "cat toto"], {})
      assert_equal result[0][:stdout], "root what"
      assert_equal result[1][:stdout], "big content"
    end
  end
end
