# This file should contain all the record creation needed to seed the database
# with its default values.
# The data can then be loaded with the rails db:seed
# command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

logger = Rails.logger

###
# USERS

logger.info "Seeding..."

DEFAULT_SUPER_ADMIN_EMAIL = 'admin@openode.io'
DEFAULT_PASSWORD = 'Mypassword1'

if !(super_admin = User.find_by(email: DEFAULT_SUPER_ADMIN_EMAIL))
  super_admin = User.create!(
    email: DEFAULT_SUPER_ADMIN_EMAIL,
    password_hash: DEFAULT_PASSWORD,
    is_admin: true,
    credits: 1000
  )
else
  logger.info "super admin already exists"
end

DEFAULT_REGULAR_USER_EMAIL = 'my@openode.io'

if !(regular_user = User.find_by(email: DEFAULT_REGULAR_USER_EMAIL))
  regular_user = User.create!(
    email: DEFAULT_REGULAR_USER_EMAIL,
    password_hash: DEFAULT_PASSWORD,
    is_admin: true,
    credits: 1000
  )
else
  logger.info "regular user already exists"
end

logger.info "Seeding complete!"

logger.info "---"
logger.info "Super admin email: #{super_admin.email}"
logger.info "Super admin password: #{DEFAULT_PASSWORD}"
logger.info "---"
logger.info "---"
logger.info "Regular user email: #{regular_user.email}"
logger.info "Regular user password: #{DEFAULT_PASSWORD}"
logger.info "---"
