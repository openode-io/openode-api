class UpdateAccountTypeFreeTo100Mb < ActiveRecord::Migration[6.0]
  def change
    websites = Website.where(account_type: 'free')

    websites.each do |website|
      Rails.logger.info("Migrating #{website.account_type} " \
                        "#{website.id} #{website.site_name}")

      website.account_type = 'second'
      website.save!

    rescue StandardError => e
      Rails.logger.error("Error with #{e}")
    end
  end
end
