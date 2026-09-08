require "rails_helper"

# Business rule: a consumer can only have ONE loyalty tally per merchant.
# `visit_summaries` enforces this at the DB level with
# UNIQUE (merchant_id, consumer_id) (see db/structure.sql). This spec confirms
# the same rule is enforced at the application level via a uniqueness
# validation, so a duplicate is rejected by `valid?`/`save` before it ever
# reaches Postgres and raises ActiveRecord::RecordNotUnique.
RSpec.describe VisitSummary, type: :model do
  def build_merchant
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

  def build_consumer
    Consumer.create!(
      first_name: "Ana",
      last_name: "Gomez",
      email: "ana.#{SecureRandom.hex(6)}@example.com",
      password_hash: "hashed-password",
      dni: SecureRandom.random_number(10**8).to_s,
      created_by: SecureRandom.uuid
    )
  end

  let(:merchant) { build_merchant }
  let(:consumer) { build_consumer }

  it "allows a single visit summary per merchant/consumer pair" do
    summary = VisitSummary.new(merchant: merchant, consumer: consumer, count: 0)

    expect(summary).to be_valid
  end

  it "rejects a second visit summary for the same merchant and consumer" do
    VisitSummary.create!(merchant: merchant, consumer: consumer, count: 3)
    duplicate = VisitSummary.new(merchant: merchant, consumer: consumer, count: 0)

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:consumer_id]).to include("has already been taken")
    expect { duplicate.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "allows the same consumer to have separate visit summaries at different merchants" do
    other_merchant = build_merchant
    VisitSummary.create!(merchant: merchant, consumer: consumer, count: 1)
    other_summary = VisitSummary.new(merchant: other_merchant, consumer: consumer, count: 0)

    expect(other_summary).to be_valid
  end
end
