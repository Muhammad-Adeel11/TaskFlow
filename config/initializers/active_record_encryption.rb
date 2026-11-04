# Keys used to encrypt the Google tokens stored in the database.
# Generate them once with:  bin/rails db:encryption:init
# and copy the three values into your .env file.
Rails.application.config.active_record.encryption.primary_key         = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
Rails.application.config.active_record.encryption.deterministic_key   = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
Rails.application.config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]