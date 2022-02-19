class RequestOrder < ApplicationRecord
    belongs_to :user

    after_create :notify_admin

    private

    def notify_admin
        SupportMailer.with(
          title: 'Crypto payment request',
          attributes: self.attributes
        ).contact.deliver_now
    end
end
