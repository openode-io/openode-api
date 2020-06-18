# snapshots_controller_test.rb

require 'test_helper'
require 'test_kubernetes_helper'

class InstancesControllerDeployKubernetesTest < ActionDispatch::IntegrationTest
  def setup
    @website = default_kube_website
    @website_location = @website.website_locations.first

    prepare_kubernetes_method(@website, @website_location)
  end

  def prepare_kubernetes_method(website, website_location)
    runner = prepare_kubernetes_runner(website, website_location)

    @kubernetes_method = runner.get_execution_method
  end

  ### Snapshots
  test 'POST /instances/:instance_id/snapshots - happy path' do
    Snapshot.destroy_all
    website = default_kube_website
    website_location = website.website_locations.first

    assert_equal website.snapshots.count, 0

    post "/instances/#{website.site_name}/snapshots",
         as: :json,
         params: {
           path: '/root/path/'
         },
         headers: default_headers_auth

    assert_response :success

    website.snapshots.reload

    snapshot = website.snapshots.last

    assert_equal website.snapshots.count, 1
    assert_equal snapshot.status, Snapshot::STATUS_PENDING

    assert response.parsed_body.dig('expires_in').to_f >= 59
    assert_equal response.parsed_body.dig('url'), snapshot.url
    assert_equal response.parsed_body.dig('details', 'id'), snapshot.id

    get_pods_json_content = IO.read('test/fixtures/kubernetes/1_pod_alive.json')
    prepare_get_pods_json(@kubernetes_method, website, website_location,
                          get_pods_json_content,
                          0)

    snapshot = website.snapshots.last

    cmd = @kubernetes_method.kubectl(
      website_location: website_location,
      s_arguments: "-n instance-#{website.id} " \
                    "cp www-deployment-5889df69dc-xg9xl" \
                    ":#{snapshot.path} #{snapshot.get_destination_folder}"
    )

    prepare_ssh_session(cmd, "", 0)

    cmd = @kubernetes_method.make_archive(
      archive_path: snapshot.get_destination_path('.zip'),
      folder_path: snapshot.get_destination_folder
    )

    prepare_ssh_session(cmd, "made archive")

    assert_scripted do
      begin_ssh

      Delayed::Job.last.invoke_job

      snapshot.reload

      assert_equal snapshot.status, Snapshot::STATUS_SUCCEED
      assert_equal snapshot.steps.length, 2
      assert_equal snapshot.steps.first.dig('name'), "copy instance files"
      assert_equal snapshot.steps[1].dig('name'), "make archive"

      assert_equal website.events.last.obj.dig('title'), "create-snapshot"
    end
  end

  test 'POST /instances/:instance_id/snapshots - issue making archive' do
    Snapshot.destroy_all
    website = default_kube_website
    website_location = website.website_locations.first

    assert_equal website.snapshots.count, 0

    post "/instances/#{website.site_name}/snapshots",
         as: :json,
         params: {
           path: '/root/path/'
         },
         headers: default_headers_auth

    assert_response :success

    website.snapshots.reload

    snapshot = website.snapshots.last

    prepare_get_pods_json(@kubernetes_method, website, website_location,
                          "",
                          1)

    assert_scripted do
      begin_ssh

      Delayed::Job.last.invoke_job

      snapshot.reload

      assert_equal snapshot.status, Snapshot::STATUS_FAILED
    end
  end
end
