
require 'test_helper'

class OpenSourceControllerTest < ActionDispatch::IntegrationTest
  test '/open_source_projects/latest' do
    w = Website.find_by site_name: 'testkubernetes-type'
    w.open_source = {
      'what': 'asdf'
    }
    w.save!

    get '/open_source_projects/latest', as: :json

    assert_response :success

    assert_equal response.parsed_body.length, 1
    assert_equal response.parsed_body[0]["site_name"], w.site_name
    assert_equal response.parsed_body[0]["status"], w.status
    assert_equal response.parsed_body[0]["open_source"], 'what' => 'asdf'
    assert_equal response.parsed_body[0]["id"].present?, true
  end

  test '/open_source_project/site_name' do
    w = Website.find_by site_name: 'testkubernetes-type'
    w.open_source = {
      'what': 'asdf'
    }
    w.save!

    get "/open_source_project/#{w.site_name}", as: :json

    assert_response :success

    assert_equal response.parsed_body["site_name"], w.site_name
    assert_equal response.parsed_body["status"], w.status
    assert_equal response.parsed_body["open_source"], 'what' => 'asdf'
    assert_equal response.parsed_body["id"].present?, true
  end

  test '/open_source_project/site_name when not open source' do
    w = default_website

    get "/open_source_project/#{w.site_name}", as: :json

    assert_response :not_found
  end
end
