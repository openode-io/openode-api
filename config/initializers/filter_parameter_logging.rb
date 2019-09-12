# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
Rails.application.config.filter_parameters += [
  :password,
  :password_hash,
  :password_confirmation,
  :encrypted_data,
  :encrypted_data_id
]
