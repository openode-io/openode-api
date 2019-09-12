class Vault < ApplicationRecord
  attr_encrypted :data, key: ENV["VAULT_SECRET"]

  def model
    self.entity_type.constantize.find_by! id: self.ref_id
  end
end
