# OpenAI configuration
# The newer OpenAI gem doesn't use configure block - configuration is done per-client
# This initializer just checks if the API key is set

# Verify configuration in development
if Rails.env.development? && ENV['OPENAI_API_KEY'].blank?
  Rails.logger.warn("⚠️  OPENAI_API_KEY not set - vector search features will not work")
end