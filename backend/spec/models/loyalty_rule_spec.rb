require "rails_helper"

# Business rule (see PRD.md and PLAN.md): a merchant's loyalty rules are
# either a one-time reward unlocked at `visits_required` visits, or a
# permanent "regular customer" perk (`is_permanent: true`) that keeps
# applying on every subsequent visit once that same threshold is reached.
# `is_permanent` changes what happens AFTER the threshold is hit — it does
# NOT remove the requirement to define the threshold itself. `visits_required`
# is mandatory and must still be a positive integer in both cases.
RSpec.describe LoyaltyRule, type: :model do
  let(:merchant) do
    Merchant.create!(
      name: "Merchant #{SecureRandom.hex(4)}",
      type: "cafe",
      address: "Av. Siempre Viva 123",
      country: "Argentina",
      state: "Buenos Aires",
      city: "CABA",
      latitude: -34.6,
      longitude: -58.4,
      created_by: SecureRandom.uuid
    )
  end

  def build_rule(attrs = {})
    LoyaltyRule.new(
      {
        merchant: merchant,
        visits_required: 10,
        reward_type: "free_item",
        reward_description: "Free dessert",
        created_by: SecureRandom.uuid
      }.merge(attrs)
    )
  end

  it "defaults to a one-time reward (is_permanent: false) when not specified" do
    rule = build_rule
    rule.save!

    expect(rule.reload.is_permanent).to eq(false)
  end

  it "allows marking a rule as a permanent regular-customer reward" do
    rule = build_rule(is_permanent: true, visits_required: 10)

    expect(rule).to be_valid
    rule.save!
    expect(rule.reload.is_permanent).to eq(true)
  end

  it "still requires a positive visits_required even for a permanent reward" do
    permanent_without_threshold = build_rule(is_permanent: true, visits_required: nil)
    permanent_with_zero_threshold = build_rule(is_permanent: true, visits_required: 0)

    expect(permanent_without_threshold).not_to be_valid
    expect(permanent_without_threshold.errors[:visits_required]).to be_present

    expect(permanent_with_zero_threshold).not_to be_valid
    expect(permanent_with_zero_threshold.errors[:visits_required]).to be_present
  end

  it "still requires a positive visits_required for a one-time (non-permanent) reward" do
    one_time_without_threshold = build_rule(is_permanent: false, visits_required: nil)

    expect(one_time_without_threshold).not_to be_valid
    expect(one_time_without_threshold.errors[:visits_required]).to be_present
  end
end
