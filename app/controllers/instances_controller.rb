class InstancesController < ApplicationController

  before_action :authorize
  before_action :populate_website

  def index
    # https://scotch.io/tutorials/build-a-restful-json-api-with-rails-5-part-one
    json_res(@user.websites)
  end

  def show
    json_res(@website)
  end

  private

  def authorize
    token = request.headers["x-auth-token"] || params["token"]

    @user = User.find_by!(token: token)
  end

  def populate_website
    if params["instance_id"]
      @website = Website.find_by!(site_name: params["instance_id"])
    end
  end

end
