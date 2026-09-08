# Shared helpers for request specs under spec/requests/api/v1.
module ApiHelpers
  # A valid, arbitrary actor id to send as the X-Actor-Id header. Since there
  # is no auth system yet (see app/controllers/concerns/trackable.rb), any
  # well-formed UUID is accepted.
  def actor_id
    @actor_id ||= SecureRandom.uuid
  end

  def actor_headers
    { "X-Actor-Id" => actor_id }
  end

  def json_response
    JSON.parse(response.body)
  end

  def create_consumer(attrs = {})
    Consumer.create!({
      first_name: "Test",
      last_name: "Consumer",
      email: "consumer-#{SecureRandom.hex(6)}@example.com",
      password_hash: "hashed-password",
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
end

RSpec.configure do |config|
  config.include ApiHelpers, type: :request
end
