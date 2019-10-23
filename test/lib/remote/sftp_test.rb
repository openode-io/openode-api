# frozen_string_literal: true

require 'test_helper'

class RemoteSftpTest < ActiveSupport::TestCase
  def setup; end

  test 'single basic file' do
    begin_sftp
    files_upload = [
      { local_file_path: '/path/to/local', remote_file_path: '/path/to/remote' }
    ]
    Remote::Sftp.transfer(files_upload, {})
  end

  test 'single basic content' do
    begin_sftp
    files_upload = [
      { content: 'hello world', remote_file_path: '/path/to/remote' }
    ]
    Remote::Sftp.transfer(files_upload, {})
  end
end
