require 'test_helper'

class LibBuildCleanTest < ActiveSupport::TestCase
  test "spend persistence - one to process, does not lack credits" do
    website = Website.find_by site_name: 'www.what.is'

    website2 = Website.find_by site_name: 'testsite'

    Website.all.each do |w|
      w.destroy unless ["www.what.is", "testsite"].include?(w.site_name)
    end

    prepare_ssh_session("ls /home/",
                        "#{website.user.id}\n #{website2.user.id}\n 1122\n docker")

    prepare_ssh_session("ls /home/#{website.user.id}/", "site1\n site2")
    prepare_ssh_session("ls /home/#{website2.user.id}/", "site1\n site2")

    prepare_ssh_session("rm -rf /home/#{website.user.id}/#{website.site_name}/", "")
    prepare_ssh_session("rm -rf /home/1122/", "")

    assert_scripted do
      begin_ssh
      invoke_task "build_clean:synced_files"
    end
  end
end
