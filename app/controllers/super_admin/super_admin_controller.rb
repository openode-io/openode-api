class SuperAdmin::SuperAdminController < ApplicationController
  before_action :authorize
  before_action :requires_admin_level

  protected

  def requires_admin_level
    authorization_error!("requires super admin level") unless @user.is_admin?
  end
end
