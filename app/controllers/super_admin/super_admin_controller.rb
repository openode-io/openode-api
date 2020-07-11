class SuperAdmin::SuperAdminController < ApplicationController
  before_action :authorize
  before_action :requires_admin_level

  def generic_index
    attribs = params['attributes'] || ''
    attributes_to_search = attribs.split(',')

    entity_method = params['entity_method']

    entity = params['entity'].constantize

    if entity_method.present?
      entity = entity.send(entity_method)
    end

    json(default_listing(entity, attributes_to_search))
  end

  protected

  def requires_admin_level
    authorization_error!("requires super admin level") unless @user.is_admin?
  end
end
