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

    # Gemini (SearchQueryParser) is prompted to return lowercase tags but
    # never guaranteed to — this filter must not silently drop matches just
    # because casing differs from what's stored.
    it "matches tags case-insensitively" do
      matching = create_merchant
      tag = Tag.create!(name: "vegano", created_by: SecureRandom.uuid)
      MerchantsTag.create!(merchant: matching, tag: tag)

      get "/api/v1/merchants", params: { tags: "VEGANO" }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |m| m["id"] }
      expect(ids).to eq([ matching.id ])
    end

    it "requires no authentication — merchant discovery is public" do
      create_merchant

      get "/api/v1/merchants"

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /api/v1/merchants/:id" do
    it "returns the merchant detail with tags and business hours, without authentication" do
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

    it "creates a merchant and stamps created_by from the authenticated consumer" do
      consumer = create_consumer

      post "/api/v1/merchants", params: { merchant: valid_attrs }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:created)
      expect(Merchant.find(json_response["id"]).created_by).to eq(consumer.id)
    end

    it "returns 422 when required fields are missing" do
      consumer = create_consumer

      post "/api/v1/merchants", params: { merchant: valid_attrs.merge(name: nil) }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("name")
    end

    it "returns 401 without authentication" do
      post "/api/v1/merchants", params: { merchant: valid_attrs }

      expect(response).to have_http_status(:unauthorized)
      expect(json_response["error"]).to eq("Not authenticated")
    end
  end

  describe "PATCH /api/v1/merchants/:id" do
    it "updates the merchant and stamps updated_by" do
      merchant = create_merchant
      consumer = create_consumer

      patch "/api/v1/merchants/#{merchant.id}", params: { merchant: { name: "Renamed" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(merchant.reload.name).to eq("Renamed")
      expect(merchant.updated_by).to eq(consumer.id)
    end

    it "returns 404 for a non-existent merchant" do
      consumer = create_consumer

      patch "/api/v1/merchants/999999", params: { merchant: { name: "Renamed" } }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without authentication" do
      merchant = create_merchant

      patch "/api/v1/merchants/#{merchant.id}", params: { merchant: { name: "Renamed" } }

      expect(response).to have_http_status(:unauthorized)
    end

    # authenticate_consumer! must run BEFORE set_merchant — otherwise a
    # non-existent id would 404 for an unauthenticated caller, leaking
    # whether that id exists to someone who was never let in at all.
    it "returns 401 (not 404) for a non-existent id without authentication" do
      patch "/api/v1/merchants/999999", params: { merchant: { name: "Renamed" } }

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/merchants/:id" do
    it "soft-deletes the merchant and cascades dependent: :destroy associations (business_hours, merchants_tags)" do
      merchant = create_merchant
      consumer = create_consumer
      tag = Tag.create!(name: "vegano", created_by: SecureRandom.uuid)
      merchants_tag = MerchantsTag.create!(merchant: merchant, tag: tag)
      business_hour = BusinessHour.create!(merchant: merchant, day_of_week: "monday", opens_at: "09:00", closes_at: "18:00")

      delete "/api/v1/merchants/#{merchant.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:no_content)
      expect(Merchant.unscoped.find(merchant.id).deleted_at).to be_present
      expect(Merchant.unscoped.find(merchant.id).deleted_by).to eq(consumer.id)
      expect(BusinessHour.where(id: business_hour.id)).not_to exist
      expect(MerchantsTag.where(id: merchants_tag.id)).not_to exist
    end

    it "fails with 422 when the merchant still has active menu items" do
      merchant = create_merchant
      consumer = create_consumer
      MenuItem.create!(merchant: merchant, name: "Item", price: 10, currency: "usd", created_by: SecureRandom.uuid)

      delete "/api/v1/merchants/#{merchant.id}", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(merchant.reload.deleted_at).to be_nil
    end

    it "returns 404 for a non-existent merchant" do
      consumer = create_consumer

      delete "/api/v1/merchants/999999", headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without authentication" do
      merchant = create_merchant

      delete "/api/v1/merchants/#{merchant.id}"

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 (not 404) for a non-existent id without authentication" do
      delete "/api/v1/merchants/999999"

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
