require 'test_helper'

class CollaboratorsControllerTest < ActionDispatch::IntegrationTest
  test '/instances/:instance_id/collaborators' do
    Collaborator.all.destroy_all
    website = default_website
    collab_user = User.where('id != ?', website.user_id).first

    collaborator = add_collaborator_for(collab_user, website, Website::PERMISSION_DNS)

    get '/instances/testsite/collaborators',
        as: :json,
        headers: default_headers_auth

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]['id'], collaborator.id
    assert_equal response.parsed_body[0]['user']['id'], collab_user.id
    assert_equal response.parsed_body[0]['user']['email'], collab_user.email
    assert_equal response.parsed_body[0]['permissions'], ['dns']
  end
end
