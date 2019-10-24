class Vault < ApplicationRecord
  attr_encrypted :data, key: ENV['VAULT_SECRET']

  def model
    entity_type.constantize.find_by! id: ref_id
  end
end
