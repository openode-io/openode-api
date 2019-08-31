class InstancesController < ApplicationController

  before_action :authorize
  before_action :populate_website
  before_action :populate_website_location
  after_action :record_website_event

  def index
    # https://scotch.io/tutorials/build-a-restful-json-api-with-rails-5-part-one
    json_res(@user.websites)
  end

  def show
    json_res(@website)
  end

  def get_config
    var_name = params["variable"]

    if ! Website.valid_config_variable?(var_name)
      msg = "Invalid variable name, Run openode available-configs for the list of valid variables."
      raise ApplicationRecord::ValidationError.new(msg)
    end

    json_res({
      result: "success",
      value: @website.configs[var_name]
    })
  end

  private

  def authorize
    token = request.headers["x-auth-token"] || params["token"]

    @user = User.find_by!(token: token)
  end

  def populate_website
    if params["site_name"]
      @website = Website.find_by! site_name: params["site_name"]
    end
  end

  def populate_website_location
    if params["location_str_id"]
      @location = Location.find_by! str_id: params["location_str_id"]
      @website_location = @website.website_locations.find_by! location_id: @location.id
    end
  end

  def record_website_event
    if @website_event_obj
      WebsiteEvent.create({ ref_id: @website.id, obj: @website_event_obj })
    end
  end
end
