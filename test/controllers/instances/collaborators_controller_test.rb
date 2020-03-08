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

  test 'POST /instances/:instance_id/collaborators' do
    Collaborator.all.destroy_all
    website = default_website
    collab_user = User.where('id != ?', website.user_id).first

    post "/instances/#{website.site_name}/collaborators",
         as: :json,
         params: { collaborator: { user_id: collab_user.id, permissions: ['dns'] } },
         headers: default_headers_auth

    assert_response :success

    Collaborator.find_by! id: response.parsed_body['id']

    assert_equal website.collaborators.length, 1
    assert_equal website.collaborators[0].user, collab_user
    assert_equal website.collaborators[0].permissions, ['dns']
  end

  test 'POST /instances/:instance_id/collaborators by email with existing user' do
    Collaborator.all.destroy_all
    website = default_website
    collab_user = User.where('id != ?', website.user_id).first

    post "/instances/#{website.site_name}/collaborators",
         as: :json,
         params: { collaborator: { email: collab_user.email, permissions: ['dns'] } },
         headers: default_headers_auth

    assert_response :success

    Collaborator.find_by! id: response.parsed_body['id']

    assert_equal website.collaborators.length, 1
    assert_equal website.collaborators[0].user, collab_user
    assert_equal website.collaborators[0].permissions, ['dns']
  end

  test 'POST /instances/:instance_id/collaborators by email without existing user' do
    Collaborator.all.destroy_all
    website = default_website
    collab_email = "invaliduser@email.com"

    assert_nil User.find_by(email: collab_email)

    post "/instances/#{website.site_name}/collaborators",
         as: :json,
         params: { collaborator: { email: collab_email, permissions: ['dns'] } },
         headers: default_headers_auth

    assert_response :success

    Collaborator.find_by! id: response.parsed_body['id']
    collab_user = User.find_by! email: collab_email

    mail_sent = ActionMailer::Base.deliveries.first
    assert_equal mail_sent.subject, 'Welcome to opeNode!'
    assert_includes mail_sent.body.raw_source, 'Activate your account'

    assert_equal website.collaborators.length, 1
    assert_equal website.collaborators[0].user, collab_user
  end

  test 'PATCH /instances/:instance_id/collaborators/id' do
    Collaborator.all.destroy_all
    website = default_website
    collab_user = User.where('id != ?', website.user_id).first

    c = add_collaborator_for(collab_user, website)

    patch "/instances/#{website.site_name}/collaborators/#{c.id}",
          as: :json,
          params: { collaborator: { permissions: [Website::PERMISSION_DNS] } },
          headers: default_headers_auth

    assert_response :success

    collaborator = Collaborator.find_by! id: c.id

    assert_equal collaborator.permissions, [Website::PERMISSION_DNS]
  end

  test 'DELETE /instances/:instance_id/collaborators/id' do
    Collaborator.all.destroy_all
    website = default_website
    collab_user = User.where('id != ?', website.user_id).first

    c = add_collaborator_for(collab_user, website)

    delete "/instances/#{website.site_name}/collaborators/#{c.id}",
           as: :json,
           params: {},
           headers: default_headers_auth

    assert_response :success

    collaborator = Collaborator.find_by id: response.parsed_body['id']

    assert_nil collaborator
  end
end
