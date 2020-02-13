class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  ValidationError = Class.new(StandardError)

  scope :search_for, lambda { |search, attributes|
    where(attributes.map { |attrib| "#{attrib} LIKE :search" }.join(" OR "), search: search)
  }

  before_destroy :destroy_secret!

  def vault
    Vault.find_by ref_id: id, entity_type: self.class.name
  end

  def save_secret!(hash)
    secret_vault = vault

    secret_vault ||= Vault.create!(
      ref_id: id,
      entity_type: self.class.name
    )

    secret_vault.data = hash.to_json
    secret_vault.save!

    secret_vault
  end

  def secret
    return nil unless vault

    JSON.parse(vault.data, symbolize_names: true)
  end

  def destroy_secret!
    existing_vault = vault

    existing_vault&.destroy
  end
end
