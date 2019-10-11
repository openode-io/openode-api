require 'test_helper'

class CreditActionTest < ActiveSupport::TestCase
	test "saves properly with enough credits, without user update" do
		website = default_website
		credits_remaining = website.user.credits
		ca = CreditAction.consume!(website, CreditAction::TYPE_CONSUME_PLAN, 1, { with_user_update: false })
		website.user.reload

		assert_equal ca.credits_spent, 1
		assert_equal ca.credits_remaining, credits_remaining
		assert_equal website.user.credits, credits_remaining
		assert_equal ca.action_type, CreditAction::TYPE_CONSUME_PLAN
	end

	test "saves properly with enough credits, with user update" do
		website = default_website
		credits_remaining = website.user.credits
		ca = CreditAction.consume!(website, CreditAction::TYPE_CONSUME, 1, { with_user_update: true })
		website.user.reload

		assert_equal ca.credits_spent, 1
		assert_equal ca.credits_remaining, credits_remaining - 1
		assert_equal website.user.credits, credits_remaining - 1
		assert_equal ca.action_type, CreditAction::TYPE_CONSUME
	end

	test "saves properly without enough credits, with user update" do
		website = default_website
		website.user.credits = 0.001
		website.user.save
		credits_remaining = website.user.credits

		begin
			CreditAction.consume!(website, CreditAction::TYPE_CONSUME, 1, { with_user_update: true })
			assert_equal true, false
		rescue
			website.user.reload
			assert_equal website.user.credits, credits_remaining
		end
	end
end
