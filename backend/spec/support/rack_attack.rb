# Rack::Attack is disabled by default in the test suite: leaving it on
# would make its throttle counters bleed across unrelated request specs
# (e.g. two unrelated tests that each hit POST /api/v1/sessions within the
# same throttle window), causing flaky, hard-to-reproduce 429s.
#
# The dedicated rate limiting spec (see
# spec/requests/api/v1/rate_limiting_spec.rb) opts back in for its own
# examples via the :rate_limited tag, and swaps in a plain in-memory cache
# store for the duration — the test environment's default Rails.cache is
# a :null_store (see config/environments/test.rb), which discards writes
# and would never let throttle counts accumulate.
Rack::Attack.enabled = false

RSpec.configure do |config|
  config.around(:each, :rate_limited) do |example|
    Rack::Attack.enabled = true
    Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new

    example.run

    Rack::Attack.enabled = false
    Rack::Attack.cache.store = Rails.cache
  end
end
