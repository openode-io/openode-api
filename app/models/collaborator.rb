class Collaborator < ApplicationRecord
  belongs_to :website
  belongs_to :user

  PERMISSION_DEPLOY = 'deploy'
  PERMISSION_DNS = 'dns'
  PERMISSION_ALIAS = 'alias'
  PERMISSION_STORAGE_AREA = 'storage_area'
  PERMISSION_LOCATION = 'location'
  PERMISSION_PLAN = 'plan'
  PERMISSION_CONFIG = 'config'
end
