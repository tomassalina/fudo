require "rails_helper"

# Business rule (see db/structure.sql and app/models/business_hour.rb): a
# merchant can run two separate shifts on the same day (e.g. lunch
# 12:00-15:30 and dinner 20:00-00:30), so (merchant_id, day_of_week) is
# intentionally NOT unique. This spec confirms the model does not carry an
# incorrect uniqueness validation that would wrongly block a double shift.
RSpec.describe BusinessHour, type: :model do
  let(:merchant) do
    Merchant.create!(
      name: "Merchant #{SecureRandom.hex(4)}",
      type: "restaurant",
      address: "Av. Siempre Viva 123",
      country: "Argentina",
      state: "Buenos Aires",
      city: "CABA",
      latitude: -34.6,
      longitude: -58.4,
      created_by: SecureRandom.uuid
    )
  end

  it "allows two separate shifts for the same merchant on the same day" do
    lunch = BusinessHour.create!(
      merchant: merchant,
      day_of_week: "monday",
      opens_at: "12:00",
      closes_at: "15:30"
    )
    dinner = BusinessHour.new(
      merchant: merchant,
      day_of_week: "monday",
      opens_at: "20:00",
      closes_at: "23:59"
    )

    expect(dinner).to be_valid
    expect { dinner.save! }.not_to raise_error

    expect(merchant.business_hours.where(day_of_week: "monday").count).to eq(2)
    expect(lunch.errors).to be_empty
  end

  it "does not validate uniqueness of day_of_week per merchant" do
    validators = BusinessHour.validators_on(:day_of_week)

    expect(validators.none? { |v| v.is_a?(ActiveRecord::Validations::UniquenessValidator) }).to be(true)
  end
end
