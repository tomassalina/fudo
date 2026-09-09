# Be sure to restart your server when you modify this file.

# Avoid CORS issues when API is called from the frontend app.
# Handle Cross-Origin Resource Sharing (CORS) in order to accept cross-origin Ajax requests.

# Read more: https://github.com/cyu/rack-cors

# Allows any localhost origin regardless of port, so a Flutter (web) or
# Next.js dev server on any port can reach the API during development.
#
# In addition, CORS_ALLOWED_ORIGINS can be set (comma-separated, e.g.
# "https://app.example.com,https://staging.example.com") to allow deployed
# web origins (e.g. the Dokploy-deployed frontend) without hardcoding
# environment-specific domains in source.
allowed_origins = ENV.fetch("CORS_ALLOWED_ORIGINS", "").split(",").map(&:strip).reject(&:empty?)

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*([%r{\Ahttps?://localhost:\d+\z}] + allowed_origins))

    resource "*",
      headers: :any,
      methods: [ :get, :post, :put, :patch, :delete, :options, :head ]
  end
end
