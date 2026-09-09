# Shared helpers for request specs under spec/requests/api/v1.
module ApiHelpers
  def json_response
    JSON.parse(response.body)
  end

  def create_consumer(attrs = {})
    Consumer.create!({
      first_name: "Test",
      last_name: "Consumer",
      email: "consumer-#{SecureRandom.hex(6)}@example.com",
      password: "password123",
      dni: SecureRandom.random_number(10**8).to_s,
      created_by: SecureRandom.uuid
    }.merge(attrs))
  end

  def create_merchant(attrs = {})
    Merchant.create!({
      name: "Merchant #{SecureRandom.hex(4)}",
      type: "restaurant",
      address: "Av. Test 123",
      country: "Argentina",
      state: "Buenos Aires",
      city: "CABA",
      neighborhood: "Palermo",
      latitude: -34.6,
      longitude: -58.4,
      price_per_person_min: 1000,
      price_per_person_max: 3000,
      created_by: SecureRandom.uuid
    }.merge(attrs))
  end

  # A valid JWT for `consumer`, built directly (no HTTP round-trip through
  # POST /api/v1/sessions) so specs that only need an authenticated
  # consumer don't also exercise — and don't get throttled by — the login
  # endpoint's rate limit (see spec/support/rack_attack.rb).
  def jwt_for(consumer)
    JsonWebToken.encode(sub: consumer.id)
  end

  def auth_headers_for(consumer)
    { "Authorization" => "Bearer #{jwt_for(consumer)}" }
  end
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
