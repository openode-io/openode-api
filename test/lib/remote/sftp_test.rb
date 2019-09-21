# https://net-ssh.github.io/ssh/v2/api/classes/Net/SSH/Test.html

require 'test_helper'

class RemoteSftpTest < ActiveSupport::TestCase

  def setup

  end

  test "single basic command" do
  	begin_sftp
  	files_upload = [
		{ local_file_path: "/path/to/local", remote_file_path: "/path/to/remote" }
	]
    Remote::Sftp.transfer(files_upload, {})
  end
end
