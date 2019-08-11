class InstancesController < ApplicationController

  before_action :authorize

  def index

    # https://scotch.io/tutorials/build-a-restful-json-api-with-rails-5-part-one

    json_response(@user.websites)
  end

  private

  def authorize
    token = request.headers["x-auth-token"] || params["token"]

    @user = User.find_by! token: token
  end

end
