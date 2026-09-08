require "rails_helper"

RSpec.describe "Api::V1::Merchants", type: :request do
  describe "GET /api/v1/merchants" do
    it "paginates and filters by neighborhood" do
      matching = create_merchant(neighborhood: "Palermo")
      create_merchant(neighborhood: "Belgrano")

      get "/api/v1/merchants", params: { neighborhood: "Palermo", per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |m| m["id"] }
      expect(ids).to eq([ matching.id ])
      expect(json_response["meta"]).to include(
        "current_page" => 1, "total_pages" => 1, "total_count" => 1, "per_page" => 5
      )
    end

    it "keeps the :list payload small — no tags/business_hours/address-level detail fields" do
      merchant = create_merchant
      tag = Tag.create!(name: "vegano", created_by: SecureRandom.uuid)
      MerchantsTag.create!(merchant: merchant, tag: tag)
      BusinessHour.create!(merchant: merchant, day_of_week: "monday", opens_at: "09:00", closes_at: "18:00")

      get "/api/v1/merchants"

      expect(response).to have_http_status(:ok)
      row = json_response["data"].first
      expect(row.keys).to include("name", "type", "neighborhood", "city")
      expect(row.keys).not_to include("tags", "business_hours", "address", "country", "state",
        "zip_code", "whatsapp_number", "delivery_url", "created_at", "updated_at")
    end

    it "returns 400 when the price_per_person filter is not numeric" do
      get "/api/v1/merchants", params: { price_per_person: "not-a-number" }

      expect(response).to have_http_status(:bad_request)
      expect(json_response["error"]).to eq("Invalid price_per_person filter value")
    end

    it "filters by a numeric price_per_person within the merchant's range" do
      matching = create_merchant(price_per_person_min: 1000, price_per_person_max: 2000)
      create_merchant(price_per_person_min: 5000, price_per_person_max: 6000)

      get "/api/v1/merchants", params: { price_per_person: 1500 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |m| m["id"] }
      expect(ids).to eq([ matching.id ])
    end
  end

  describe "GET /api/v1/merchants/:id" do
    it "returns the merchant detail with tags and business hours" do
      merchant = create_merchant
      tag = Tag.create!(name: "vegano", created_by: SecureRandom.uuid)
      MerchantsTag.create!(merchant: merchant, tag: tag)

      get "/api/v1/merchants/#{merchant.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(merchant.id)
      expect(json_response["tags"]).to eq([ "vegano" ])
      expect(json_response["business_hours"]).to eq([])
    end

    it "returns 404 for a non-existent merchant" do
      get "/api/v1/merchants/999999"

      expect(response).to have_http_status(:not_found)
      expect(json_response["error"]).to eq("Resource not found")
    end
  end

  describe "POST /api/v1/merchants" do
    let(:valid_attrs) do
      {
        name: "New Merchant", type: "restaurant", address: "Av. Test 1",
        country: "Argentina", state: "Buenos Aires", city: "CABA",
        latitude: -34.6, longitude: -58.4
      }
    end

    it "creates a merchant and stamps created_by from X-Actor-Id" do
      post "/api/v1/merchants", params: { merchant: valid_attrs }, headers: actor_headers

      expect(response).to have_http_status(:created)
      expect(Merchant.find(json_response["id"]).created_by).to eq(actor_id)
    end

    it "returns 422 when required fields are missing" do
      post "/api/v1/merchants", params: { merchant: valid_attrs.merge(name: nil) }, headers: actor_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("name")
    end

    it "returns 400 without an X-Actor-Id header" do
      post "/api/v1/merchants", params: { merchant: valid_attrs }

      expect(response).to have_http_status(:bad_request)
      expect(json_response["error"]).to eq("Missing or invalid X-Actor-Id header")
    end
  end

  describe "PATCH /api/v1/merchants/:id" do
    it "updates the merchant and stamps updated_by" do
      merchant = create_merchant

      patch "/api/v1/merchants/#{merchant.id}", params: { merchant: { name: "Renamed" } }, headers: actor_headers

      expect(response).to have_http_status(:ok)
      expect(merchant.reload.name).to eq("Renamed")
      expect(merchant.updated_by).to eq(actor_id)
    end

    it "returns 404 for a non-existent merchant" do
      patch "/api/v1/merchants/999999", params: { merchant: { name: "Renamed" } }, headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/merchants/:id" do
    it "soft-deletes the merchant and cascades dependent: :destroy associations (business_hours, merchants_tags)" do
      merchant = create_merchant
      tag = Tag.create!(name: "vegano", created_by: SecureRandom.uuid)
      merchants_tag = MerchantsTag.create!(merchant: merchant, tag: tag)
      business_hour = BusinessHour.create!(merchant: merchant, day_of_week: "monday", opens_at: "09:00", closes_at: "18:00")

      delete "/api/v1/merchants/#{merchant.id}", headers: actor_headers

      expect(response).to have_http_status(:no_content)
      expect(Merchant.unscoped.find(merchant.id).deleted_at).to be_present
      expect(Merchant.unscoped.find(merchant.id).deleted_by).to eq(actor_id)
      expect(BusinessHour.where(id: business_hour.id)).not_to exist
      expect(MerchantsTag.where(id: merchants_tag.id)).not_to exist
    end

    it "fails with 422 when the merchant still has active menu items" do
      merchant = create_merchant
      MenuItem.create!(merchant: merchant, name: "Item", price: 10, currency: "usd", created_by: SecureRandom.uuid)

      delete "/api/v1/merchants/#{merchant.id}", headers: actor_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(merchant.reload.deleted_at).to be_nil
    end

    it "returns 404 for a non-existent merchant" do
      delete "/api/v1/merchants/999999", headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
