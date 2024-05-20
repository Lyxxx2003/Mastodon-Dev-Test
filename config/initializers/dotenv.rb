# Load environment variables from .env and .env.[environment]
Dotenv.load('.env', ".env.#{Rails.env}", ".env.#{Rails.env}.local")

