require "rails_helper"

RSpec.describe "Api::V1::Favorites", type: :request do
  def create_favorite(attrs = {})
    consumer = attrs.delete(:consumer) || create_consumer
    merchant = attrs.delete(:merchant) || create_merchant
    Favorite.create!({ consumer: consumer, merchant: merchant, created_by: SecureRandom.uuid }.merge(attrs))
  end

  describe "GET /api/v1/favorites" do
    it "paginates and filters by consumer_id" do
      consumer = create_consumer
      matching = create_favorite(consumer: consumer)
      create_favorite

      get "/api/v1/favorites", params: { consumer_id: consumer.id, per_page: 5 }

      expect(response).to have_http_status(:ok)
      ids = json_response["data"].map { |f| f["id"] }
      expect(ids).to eq([ matching.id ])
    end

    # Postgres's uuid column type-casts client-side (see
    # ActiveRecord::ConnectionAdapters::PostgreSQL::OID::Uuid#cast_value):
    # anything that doesn't already look like a UUID is cast to nil before
    # it ever reaches SQL, so this never raises — it's just an empty result.
    it "returns an empty (not an error) result when the consumer_id filter is not a valid UUID" do
      create_favorite

      get "/api/v1/favorites", params: { consumer_id: "not-a-uuid" }

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
    end
  end

  describe "GET /api/v1/favorites/:id" do
    it "returns the favorite" do
      favorite = create_favorite

      get "/api/v1/favorites/#{favorite.id}"

      expect(response).to have_http_status(:ok)
      expect(json_response["id"]).to eq(favorite.id)
    end

    it "returns 404 for a non-existent favorite" do
      get "/api/v1/favorites/999999"

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/favorites" do
    it "creates a favorite" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/favorites", params: { favorite: { consumer_id: consumer.id, merchant_id: merchant.id } }, headers: actor_headers

      expect(response).to have_http_status(:created)
      expect(Favorite.find(json_response["id"]).created_by).to eq(actor_id)
    end

    it "returns 422 for a duplicate consumer/merchant pair" do
      favorite = create_favorite

      post "/api/v1/favorites",
        params: { favorite: { consumer_id: favorite.consumer_id, merchant_id: favorite.merchant_id } },
        headers: actor_headers

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json_response["errors"]).to have_key("merchant_id")
    end

    it "returns 400 without an X-Actor-Id header" do
      consumer = create_consumer
      merchant = create_merchant

      post "/api/v1/favorites", params: { favorite: { consumer_id: consumer.id, merchant_id: merchant.id } }

      expect(response).to have_http_status(:bad_request)
    end

    # Rails' own uniqueness validator queries via `klass.unscoped`
    # (active_record/validations/uniqueness.rb), so it already sees a
    # soft-deleted row through `default_scope` and blocks a plain
    # re-favorite with a 422 — the DB's unconditional unique index on
    # (consumer_id, merchant_id) is never reached that way. What it does NOT
    # protect against is a race: two concurrent creates can both pass
    # validation before either has committed, so the second INSERT can still
    # hit the DB constraint directly. Simulate that race by bypassing model
    # validation, and confirm the base controller turns that into a 409
    # instead of an unhandled 500.
    it "returns 409 instead of a raw 500 if a duplicate reaches the DB unique index" do
      existing = create_favorite
      allow_any_instance_of(Favorite).to receive(:valid?).and_return(true)

      post "/api/v1/favorites",
        params: { favorite: { consumer_id: existing.consumer_id, merchant_id: existing.merchant_id } },
        headers: actor_headers

      expect(response).to have_http_status(:conflict)
      expect(json_response["error"]).to eq("Resource already exists")
    end
  end

  describe "PATCH /api/v1/favorites/:id" do
    it "updates the favorite" do
      favorite = create_favorite
      other_merchant = create_merchant

      patch "/api/v1/favorites/#{favorite.id}", params: { favorite: { merchant_id: other_merchant.id } }

      expect(response).to have_http_status(:ok)
      expect(favorite.reload.merchant_id).to eq(other_merchant.id)
    end

    it "returns 404 for a non-existent favorite" do
      patch "/api/v1/favorites/999999", params: { favorite: { merchant_id: create_merchant.id } }

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v1/favorites/:id" do
    it "soft-deletes the favorite" do
      favorite = create_favorite

      delete "/api/v1/favorites/#{favorite.id}", headers: actor_headers

      expect(response).to have_http_status(:no_content)
      expect(Favorite.unscoped.find(favorite.id).deleted_at).to be_present
    end

    it "returns 404 for a non-existent favorite" do
      delete "/api/v1/favorites/999999", headers: actor_headers

      expect(response).to have_http_status(:not_found)
    end
  end
end
