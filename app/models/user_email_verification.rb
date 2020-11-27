class UserEmailVerification < History
  belongs_to :user, foreign_key: :ref_id
end
