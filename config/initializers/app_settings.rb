# config/initializers/app_settings.rb

# Define your settings here
AppSettings = OpenStruct.new(
  verified_identity: {
    service_name: 'default_service_name',
    private_key: 'default_private_key',
    enable_verified_identity: false,
    allow_anonymous_profiles: false,
    allow_anonymous_posts: false
  }
)
