require "rails_helper"

# BusinessHour has no audit columns (see db/structure.sql) so no X-Actor-Id
# is required here, and destroy is a real DELETE (no deleted_at column).
RSpec.describe "Api::V1::BusinessHours", type: :request do
  def create_business_hour(attrs = {})
    merchant = attrs.delete(:merchant) || create_merchant
    BusinessHour.create!({ merchant: merchant, day_of_week: "monday", opens_at: "09:00", closes_at: "18:00" }.merge(attrs))
  end

  describe "GET /api/v1/business_hours" do
    it "paginates and filters by merchant_id" do
      merchant = create_merchant
      matching = create_business_hour(merchant: merchant)
      create_business_hour

      get "/api/v1/business_hours", params: { merchant_id: merchant.id, per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |b| b["id"] }
      expect(ids).to eq([ matching.id ])
    end
  end

  describe "GET /api/v1/business_hours/:id" do
    it "returns the business hour" do
      business_hour = create_business_hour

      get "/api/v1/business_hours/#{business_hour.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(business_hour.id)
    end

    it "returns 404 for a non-existent business hour" do
      get "/api/v1/business_hours/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/business_hours" do
    it "creates a business hour without needing an X-Actor-Id header" do
      merchant = create_merchant

      post "/api/v1/business_hours",
        params: { business_hour: { merchant_id: merchant.id, day_of_week: "tuesday", opens_at: "10:00", closes_at: "20:00" } }

      expect(response).to have_http_status(:created)
    end

    it "returns 422 when day_of_week is missing" do
      merchant = create_merchant

      post "/api/v1/business_hours", params: { business_hour: { merchant_id: merchant.id, day_of_week: nil } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("day_of_week")
    end
  end

  describe "PATCH /api/v1/business_hours/:id" do
    it "updates the business hour" do
      business_hour = create_business_hour

      patch "/api/v1/business_hours/#{business_hour.id}", params: { business_hour: { closed: true } }

      expect(response).to have_http_status(:ok)
      expect(business_hour.reload.closed).to be(true)
    end

    it "returns 404 for a non-existent business hour" do
      patch "/api/v1/business_hours/999999", params: { business_hour: { closed: true } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/business_hours/:id" do
    it "hard-deletes the business hour" do
      business_hour = create_business_hour

      delete "/api/v1/business_hours/#{business_hour.id}"

      expect(response).to have_http_status(:no_content)
      expect(BusinessHour.where(id: business_hour.id)).not_to exist
    end

    it "returns 404 for a non-existent business hour" do
      delete "/api/v1/business_hours/999999"

      expect(response).to have_http_status(:not_found)
    end
  end
end
