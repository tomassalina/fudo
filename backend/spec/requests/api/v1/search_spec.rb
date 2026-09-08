require "rails_helper"

# This spec makes REAL calls to the Gemini API (no VCR, no mocking of
# SearchQueryParser/Gemini) to exercise the actual natural-language parsing
# integration end to end. Because Gemini's output is non-deterministic, the
# assertions below check the SHAPE and types of the structured output
# (neighborhood/type/tags/price_per_person keys and types), not exact
# content values.
#
# Requires a valid GEMINI_API_KEY with available quota in this environment.
RSpec.describe "Api::V1::Search", type: :request do
  QUERIES = [
    "algo picante y barato en Palermo",
    "un café tranquilo en Recoleta",
    "pizza vegetariana en Belgrano sin importar el precio",
    "un bar con buena onda"
  ].freeze

  describe "POST /api/v1/search" do
    QUERIES.each do |query|
      it "parses \"#{query}\" into structured filters and returns matching merchants" do
        consumer = create_consumer

        expect {
          post "/api/v1/search",
            params: { query: query, consumer_id: consumer.id },
            headers: actor_headers
        }.to change(SearchHistory, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key("data")
        expect(json_response).to have_key("meta")

        search_history = SearchHistory.order(:id).last
        expect(search_history.consumer_id).to eq(consumer.id)
        expect(search_history.query_text).to eq(query)
        expect(search_history.created_by).to eq(actor_id)

        structured_output = search_history.structured_output
        expect(structured_output).to be_a(Hash).or be_a(ActiveSupport::HashWithIndifferentAccess)
        expect(structured_output.keys).to include("neighborhood", "type", "tags", "price_per_person")
        expect(structured_output["neighborhood"]).to be_a(String).or be_nil
        expect(structured_output["type"]).to be_a(String).or be_nil
        expect(structured_output["type"]).to satisfy("be a valid merchant type or nil") do |type|
          type.nil? || Merchant.types.key?(type)
        end
        expect(structured_output["tags"]).to be_a(Array)
        expect(structured_output["tags"]).to all(be_a(String))
        expect(structured_output["price_per_person"]).to be_a(Numeric).or be_nil
      end
    end

    it "returns 400 without an X-Actor-Id header" do
      consumer = create_consumer

      post "/api/v1/search", params: { query: "pizza", consumer_id: consumer.id }

      expect(response).to have_http_status(:bad_request)
    end

    it "returns 400 when query is missing" do
      consumer = create_consumer

      post "/api/v1/search", params: { consumer_id: consumer.id }, headers: actor_headers

      expect(response).to have_http_status(:bad_request)
    end
  end
end
