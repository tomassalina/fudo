require "rails_helper"

# This spec makes REAL calls to the Gemini API (no VCR, no mocking of
# SearchQueryParser/Gemini) to exercise the actual natural-language parsing
# integration end to end. Because Gemini's output is non-deterministic, the
# assertions below check the SHAPE and types of the structured output
# (neighborhood/type/tags/price_per_person/open/reward keys and types), not
# exact content values.
#
# Requires a valid GEMINI_API_KEY with available quota in this environment.
RSpec.describe "Api::V1::Search", type: :request do
  QUERIES = [
    "algo picante y barato en Palermo",
    "un café tranquilo en Recoleta",
    "pizza vegetariana en Belgrano sin importar el precio",
    "un bar con buena onda",
    "un bar abierto ahora que tenga premio por visitas"
  ].freeze

  describe "POST /api/v1/search" do
    QUERIES.each do |query|
      it "parses \"#{query}\" into structured filters and returns matching merchants" do
        consumer = create_consumer

        expect {
          post "/api/v1/search", params: { query: query }, headers: auth_headers_for(consumer)
        }.to change(SearchHistory, :count).by(1)

        expect(response).to have_http_status(:ok)
        expect(json_response).to have_key("data")
        expect(json_response).to have_key("meta")
        expect(json_response).to have_key("filters")

        search_history = SearchHistory.order(:id).last
        expect(search_history.consumer_id).to eq(consumer.id)
        expect(search_history.query_text).to eq(query)
        expect(search_history.created_by).to eq(consumer.id)

        structured_output = search_history.structured_output
        expect(structured_output).to be_a(Hash).or be_a(ActiveSupport::HashWithIndifferentAccess)
        expect(structured_output.keys).to include(
          "neighborhood", "type", "tags", "price_per_person", "open", "reward"
        )
        expect(structured_output["neighborhood"]).to be_a(String).or be_nil
        expect(structured_output["type"]).to be_a(String).or be_nil
        expect(structured_output["type"]).to satisfy("be a valid merchant type or nil") do |type|
          type.nil? || Merchant.types.key?(type)
        end
        expect(structured_output["tags"]).to be_a(Array)
        expect(structured_output["tags"]).to all(be_a(String))
        # Every tag Gemini returns must be one of the real, currently-seeded
        # tags — the whole point of the dynamic enum in
        # SearchQueryParser.response_schema (see its own doc comment).
        allowed_tags = Tag.order(:name).pluck(:name).map(&:downcase)
        expect(structured_output["tags"].map(&:downcase)).to all(be_in(allowed_tags))
        expect(structured_output["price_per_person"]).to be_a(Numeric).or be_nil
        expect(structured_output["open"]).to be_in([ true, false, nil ])
        expect(structured_output["reward"]).to be_in([ true, false, nil ])

        # The response's `filters` must be the exact same structured output
        # persisted to search_history — a client builds the shareable
        # /buscar URL straight from this field, so it must never drift from
        # what was actually parsed/saved.
        expect(json_response["filters"]).to eq(structured_output.as_json)
      end
    end

    it "returns 200 without authentication and does not persist search history" do
      expect {
        post "/api/v1/search", params: { query: "pizza" }
      }.not_to change(SearchHistory, :count)

      expect(response).to have_http_status(:ok)
      expect(json_response).to have_key("data")
      expect(json_response).to have_key("meta")
      expect(json_response).to have_key("filters")
    end

    it "returns 400 when query is missing" do
      consumer = create_consumer

      post "/api/v1/search", params: {}, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:bad_request)
    end

    it "does not leak into another consumer's search history" do
      consumer = create_consumer
      other = create_consumer

      get "/api/v1/search_histories", params: { consumer_id: other.id }, headers: auth_headers_for(consumer)

      expect(response).to have_http_status(:ok)
      expect(json_response["data"]).to eq([])
    end
  end
end
