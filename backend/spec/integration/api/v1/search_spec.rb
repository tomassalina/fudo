require "swagger_helper"

# The natural-language search endpoint calls the Gemini API through
# SearchQueryParser (see app/services/search_query_parser.rb). To keep this
# documentation spec deterministic and independent of Gemini's live
# availability/billing status, SearchQueryParser.call is stubbed here rather
# than exercised end to end — the real integration is already covered by
# spec/requests/api/v1/search_spec.rb, which makes genuine Gemini calls.
RSpec.describe "Search", type: :request do
  # Documentation-only literal, NOT a re-hardcoding of the production
  # constraint: SearchQueryParser.response_schema itself sources this
  # dynamically from `Tag.order(:name).pluck(:name)` (see its own doc
  # comment) so it can never go stale after a live tag change — but a query
  # against the live tags table isn't usable here, since this file's `schema`
  # blocks run at RSpec's example-tree-build time, before any `before` hook
  # seeds test data, against whatever the (likely empty) test DB happens to
  # hold at that moment. Kept in sync with db/seeds.rb's TAG_NAMES by hand.
  seeded_tag_names = %w[sin_tacc vegano vegetariano picante economico].freeze

  merchant_list_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      name: { type: :string },
      type: { type: :string, enum: Merchant.types.keys },
      neighborhood: { type: :string, nullable: true },
      city: { type: :string },
      price_per_person_min: { type: :string, nullable: true },
      price_per_person_max: { type: :string, nullable: true },
      cover_image_url: { type: :string, nullable: true },
      latitude: { type: :string },
      longitude: { type: :string }
    },
    required: %w[id name type city latitude longitude]
  }.freeze

  path "/api/v1/search" do
    post "Parses a free-text query into merchant filters and returns matching merchants" do
      tags "Search"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "Persists the query and its parsed filters to the authenticated consumer's search " \
        "history (SearchHistory), then filters merchants the same way GET /api/v1/merchants does."
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: { query: { type: :string } },
        required: %w[query]
      }

      response "200", "query parsed and matching merchants returned" do
        schema type: :object,
          properties: {
            data: { type: :array, items: merchant_list_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" },
            filters: {
              type: :object,
              description: "The structured filters Gemini derived from the free-text query " \
                "(same shape as SearchHistory#structured_output) — lets a client build a " \
                "shareable /buscar?type=...&hood=...&open=now&reward=1 URL out of a " \
                "natural-language search.",
              properties: {
                neighborhood: { type: :string, nullable: true },
                type: { type: :string, nullable: true, enum: Merchant.types.keys },
                tags: { type: :array, items: { type: :string, enum: seeded_tag_names } },
                price_per_person: { type: :number, nullable: true },
                open: { type: :boolean, nullable: true, description: "\"Abierto ahora\" — maps onto /buscar's open=now param." },
                reward: { type: :boolean, nullable: true, description: "\"Premio por visitas\" — maps onto /buscar's reward=1 param." }
              },
              required: %w[neighborhood type tags price_per_person open reward]
            }
          },
          required: %w[data meta filters]

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:body) { { query: "algo picante y barato en Palermo" } }
        before do
          create_merchant(neighborhood: "Palermo")
          allow(SearchQueryParser).to receive(:call).and_return(
            {
              "neighborhood" => "Palermo", "type" => nil, "tags" => [], "price_per_person" => nil,
              "open" => nil, "reward" => nil
            }
          )
        end
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:body) { { query: "pizza" } }
        run_test!
      end

      response "400", "query is missing" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:body) { {} }
        run_test!
      end

      response "502", "the search parsing service (Gemini) is unavailable" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:body) { { query: "pizza" } }
        before { allow(SearchQueryParser).to receive(:call).and_raise(SearchQueryParser::GeminiError, "boom") }
        run_test!
      end
    end
  end
end
