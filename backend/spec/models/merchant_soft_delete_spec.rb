require "rails_helper"

# Regression spec for the belongs_to_required_by_default (Rails 7.2+) +
# Merchant's soft-delete default_scope interaction: without unscoping
# deleted_at on `belongs_to :merchant` (see the comment on each affected
# model), ANY save on one of these child records after their merchant gets
# soft-deleted would fail validation with "Merchant must exist" — even
# though merchant_id itself never changed and the row is otherwise
# perfectly valid.
RSpec.describe "Merchant soft-delete does not break existing children", type: :model do
  let(:actor_id) { SecureRandom.uuid }

  let(:merchant) do
    Merchant.create!(
      name: "Merchant #{SecureRandom.hex(4)}", type: "restaurant", address: "Av. Siempre Viva 123",
      country: "Argentina", state: "Buenos Aires", city: "CABA", latitude: -34.6, longitude: -58.4,
      created_by: actor_id
    )
  end

  def create_consumer
    Consumer.create!(
      first_name: "T", last_name: "T", email: "t#{SecureRandom.hex(6)}@example.com",
      password: "password123", dni: SecureRandom.random_number(10**8).to_s, created_by: actor_id
    )
  end

  it "lets a menu item be updated after both it and its merchant are soft-deleted" do
    menu_item = MenuItem.create!(merchant: merchant, name: "Item", price: 10, currency: "usd", created_by: actor_id)
    # menu_items has dependent: :restrict_with_error on Merchant, so it must
    # already be soft-deleted (not "active") before the merchant's own
    # soft-delete is even allowed to proceed.
    menu_item.soft_delete!(actor_id)
    merchant.soft_delete!(actor_id)

    menu_item.reload
    expect { menu_item.update!(name: "Renamed", updated_by: actor_id) }.not_to raise_error
  end

  it "lets a loyalty rule be updated after both it and its merchant are soft-deleted" do
    rule = LoyaltyRule.create!(merchant: merchant, visits_required: 5, reward_type: "free_item",
      reward_description: "Free coffee", created_by: actor_id)
    rule.soft_delete!(actor_id)
    merchant.soft_delete!(actor_id)

    rule.reload
    expect { rule.update!(reward_description: "Free coffee, updated", updated_by: actor_id) }.not_to raise_error
  end

  it "lets a visit be updated after both it and its merchant are soft-deleted" do
    consumer = create_consumer
    visit = Visit.create!(consumer: consumer, merchant: merchant, amount: 100, visited_at: Time.current, created_by: actor_id)
    visit.soft_delete!(actor_id)
    merchant.soft_delete!(actor_id)

    visit.reload
    expect { visit.update!(amount: 200, updated_by: actor_id) }.not_to raise_error
  end

  it "lets a favorite be saved again after both it and its merchant are soft-deleted" do
    consumer = create_consumer
    favorite = Favorite.create!(consumer: consumer, merchant: merchant, created_by: actor_id)
    favorite.soft_delete!(actor_id)
    merchant.soft_delete!(actor_id)

    favorite.reload
    expect { favorite.save! }.not_to raise_error
  end

  it "cascades business hours (dependent: :destroy) when the merchant is soft-deleted, leaving none to update" do
    business_hour = BusinessHour.create!(merchant: merchant, day_of_week: "monday", opens_at: "09:00", closes_at: "18:00")

    merchant.soft_delete!(actor_id)

    expect(BusinessHour.where(id: business_hour.id)).not_to exist
  end

  it "cascades visit summaries (dependent: :destroy) when the merchant is soft-deleted, leaving none to update" do
    consumer = create_consumer
    visit_summary = VisitSummary.create!(consumer: consumer, merchant: merchant, count: 1)

    merchant.soft_delete!(actor_id)

    expect(VisitSummary.where(id: visit_summary.id)).not_to exist
  end

  it "requires an actor_id — soft_delete! must not silently drop the audit trail" do
    expect { merchant.soft_delete!(nil) }.to raise_error(ArgumentError, /actor_id is required/)
    expect(merchant.reload.deleted_at).to be_nil
  end
end
