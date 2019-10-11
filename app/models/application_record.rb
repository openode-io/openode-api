class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  ValidationError = Class.new(StandardError)

  before_destroy :destroy_secret!

  def vault
    Vault.find_by ref_id: self.id, entity_type: self.class.name
  end

  def save_secret!(hash)
    secret_vault = self.vault

    unless secret_vault
      secret_vault = Vault.create!({
        ref_id: self.id,
        entity_type: self.class.name
      })
    end

    secret_vault.data = hash.to_json
    secret_vault.save!

    secret_vault
  end

  def secret
    return nil unless self.vault

    JSON.parse(self.vault.data, :symbolize_names => true)
  end

  def destroy_secret!
    existing_vault = self.vault

    existing_vault.destroy if existing_vault
  end
end
