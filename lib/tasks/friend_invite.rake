
namespace :update do
  desc ''
  task friend_invites: :environment do
    task_name = "Task update__friend_invites"
    Rails.logger.info "[#{task_name}] begin"

    invites = FriendInvite.where(status: FriendInvite::STATUS_PENDING)

    invites.each do |invite|
      Rails.logger.info "[#{task_name}] current invite... #{invite.inspect}"

      email_invite = invite.email
      user_invited = User.find_by email: email_invite

      days_elapsed = (Time.now - invite.created_at) / (60 * 60 * 24)

      if user_invited && user_invited.activated
        # change status
        invite.status = FriendInvite::STATUS_APPROVED
        invite.save
        Rails.logger.info "[#{task_name}] invite marked as approved"

        order = Order.create!(
          user_id: invite.user.id,
          amount: 1,
          payment_status: "Completed",
          gateway: "credit",
          content: { reason: "friend invite" }
        )

        Rails.logger.info "[#{task_name}] order created #{order.inspect}"

        invite.order = order
        invite.save
      elsif days_elapsed >= 7
        Rails.logger.info "[#{task_name}] invite too old... destroying invite #{invite.id}"
        invite.destroy
      end
    end
  end
end

