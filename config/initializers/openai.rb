# OpenAI configuration
OpenAI.configure do |config|
  config.access_token = ENV.fetch('OPENAI_API_KEY', nil)
  config.request_timeout = 30 # seconds
end

# Verify configuration in development
if Rails.env.development? && ENV['OPENAI_API_KEY'].blank?
  Rails.logger.warn("⚠️  OPENAI_API_KEY not set - vector search features will not work")
end