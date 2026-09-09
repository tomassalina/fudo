# Rate limiting / basic abuse protection for the public API.
class Rack::Attack
  # Uses Rails' default cache store to track request counts. In production,
  # Rails.cache is Solid Cache (config.cache_store = :solid_cache_store,
  # see config/environments/production.rb), backed by the app's primary
  # Postgres database (config/cache.yml) — a shared store every app
  # process/dyno reads and writes through, so these throttle counts hold
  # globally across the whole fleet, not just per process.
  self.cache.store = Rails.cache

  # Aggressive throttle on the auth endpoints to slow down credential
  # brute-forcing and registration abuse: 5 attempts per 20 seconds per IP.
  #
  # Matched with a regex (optional trailing ".json"/etc.) rather than
  # `req.path == "/api/v1/sessions"` — an exact-string match lets
  # "/api/v1/sessions.json" (still routed to the same action by Rails)
  # dodge this throttle entirely and fall through to the much laxer
  # general API throttle below.
  SESSIONS_PATH = %r{\A/api/v1/sessions(\.\w+)?\z}
  REGISTRATIONS_PATH = %r{\A/api/v1/registrations(\.\w+)?\z}

  throttle("sessions/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.post? && req.path.match?(SESSIONS_PATH)
  end

  throttle("registrations/ip", limit: 5, period: 20.seconds) do |req|
    req.ip if req.post? && req.path.match?(REGISTRATIONS_PATH)
  end

  # Looser general throttle across the whole API to blunt generic abuse:
  # 300 requests per 5 minutes per IP.
  throttle("api/ip", limit: 300, period: 5.minutes) do |req|
    req.ip if req.path.start_with?("/api/v1/")
  end

  self.throttled_responder = lambda do |request|
    match_data = request.env["rack.attack.match_data"] || {}
    retry_after = match_data[:period]

    headers = { "Content-Type" => "application/json" }
    headers["Retry-After"] = retry_after.to_s if retry_after

    [ 429, headers, [ { error: "Too many requests. Please try again later." }.to_json ] ]
  end
end
