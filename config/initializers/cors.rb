# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins do |source, env|
      # Allow any localhost port
      if source =~ /\Ahttp:\/\/localhost:\d+\z/
        true
      # Allow any 100.104.170.10 port in 8000-8999 range
      elsif source =~ /\Ahttp:\/\/100\.104\.170\.10:8\d{3}\z/
        true
      # Allow production domain
      elsif source == "https://offline.oknotok.com"
        true
      elsif source == "https://dev.offline.oknotok.com"
        true

      else
        false
      end
    end

    resource "*",
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      expose: ["Authorization", "Content-Type"],
      credentials: true
  end
end
