# config/initializers/verified_identity.rb
Rails.application.config.after_initialize do
    if ActiveRecord::Base.connection.table_exists?('verified_identity_settings')
      settings = VerifiedIdentitySetting.first_or_initialize
      if settings.enable_verified_identity
        Rails.application.config.truanon_service_name = settings.service_name
        Rails.application.config.truanon_private_key = settings.private_key
      end
    end
end
  
