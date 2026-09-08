require "swagger_helper"

RSpec.describe "LoyaltyRules", type: :request do
  loyalty_rule_list_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      merchant_id: { type: :integer },
      visits_required: { type: :integer },
      reward_type: { type: :string, enum: LoyaltyRule.reward_types.keys },
      reward_description: { type: :string },
      is_permanent: { type: :boolean }
    },
    required: %w[id merchant_id visits_required reward_type reward_description is_permanent]
  }.freeze

  loyalty_rule_extended = {
    type: :object,
    properties: loyalty_rule_list_item[:properties].merge(
      created_at: { type: :string },
      updated_at: { type: :string }
    ),
    required: loyalty_rule_list_item[:required] + %w[created_at updated_at]
  }.freeze

  path "/api/v1/loyalty_rules" do
    get "Lists loyalty rules" do
      tags "LoyaltyRules"
      produces "application/json"
      description "Public — no authentication required."
      parameter name: :merchant_id, in: :query, schema: { type: :integer }, required: false,
        description: "Filter by merchant"
      parameter name: :page, in: :query, schema: { type: :integer }, required: false
      parameter name: :per_page, in: :query, schema: { type: :integer }, required: false

      response "200", "loyalty rules found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: loyalty_rule_list_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        let(:merchant) { create_merchant }
        before do
          LoyaltyRule.create!(merchant: merchant, visits_required: 10, reward_type: "free_item",
            reward_description: "Free dessert", created_by: SecureRandom.uuid)
        end
        run_test!
      end
    end

    post "Creates a loyalty rule" do
      tags "LoyaltyRules"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :loyalty_rule, in: :body, schema: {
        type: :object,
        properties: {
          loyalty_rule: {
            type: :object,
            properties: {
              merchant_id: { type: :integer },
              visits_required: { type: :integer },
              reward_type: { type: :string, enum: LoyaltyRule.reward_types.keys },
              reward_description: { type: :string },
              is_permanent: { type: :boolean }
            },
            required: %w[merchant_id visits_required reward_type reward_description]
          }
        },
        required: %w[loyalty_rule]
      }

      response "201", "loyalty rule created" do
        schema loyalty_rule_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:loyalty_rule) do
          { loyalty_rule: { merchant_id: merchant.id, visits_required: 10, reward_type: "free_item", reward_description: "Free dessert" } }
        end
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:merchant) { create_merchant }
        let(:loyalty_rule) { { loyalty_rule: { merchant_id: merchant.id, visits_required: 10, reward_type: "free_item", reward_description: "x" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:loyalty_rule) { { loyalty_rule: { merchant_id: merchant.id, visits_required: -1, reward_type: "free_item", reward_description: "x" } } }
        run_test!
      end
    end
  end

  path "/api/v1/loyalty_rules/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a loyalty rule" do
      tags "LoyaltyRules"
      produces "application/json"
      description "Public — no authentication required."

      response "200", "loyalty rule found" do
        schema loyalty_rule_extended

        let(:id) do
          LoyaltyRule.create!(merchant: create_merchant, visits_required: 10, reward_type: "free_item",
            reward_description: "Free dessert", created_by: SecureRandom.uuid).id
        end
        run_test!
      end

      response "404", "loyalty rule not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a loyalty rule" do
      tags "LoyaltyRules"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :loyalty_rule, in: :body, schema: {
        type: :object,
        properties: {
          loyalty_rule: {
            type: :object,
            properties: {
              visits_required: { type: :integer },
              reward_type: { type: :string, enum: LoyaltyRule.reward_types.keys },
              reward_description: { type: :string },
              is_permanent: { type: :boolean }
            }
          }
        }
      }

      response "200", "loyalty rule updated" do
        schema loyalty_rule_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) do
          LoyaltyRule.create!(merchant: create_merchant, visits_required: 10, reward_type: "free_item",
            reward_description: "Free dessert", created_by: SecureRandom.uuid).id
        end
        let(:loyalty_rule) { { loyalty_rule: { is_permanent: true } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          LoyaltyRule.create!(merchant: create_merchant, visits_required: 10, reward_type: "free_item",
            reward_description: "Free dessert", created_by: SecureRandom.uuid).id
        end
        let(:loyalty_rule) { { loyalty_rule: { is_permanent: true } } }
        run_test!
      end

      response "404", "loyalty rule not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:loyalty_rule) { { loyalty_rule: { is_permanent: true } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) do
          LoyaltyRule.create!(merchant: create_merchant, visits_required: 10, reward_type: "free_item",
            reward_description: "Free dessert", created_by: SecureRandom.uuid).id
        end
        let(:loyalty_rule) { { loyalty_rule: { visits_required: -1 } } }
        run_test!
      end
    end

    delete "Soft-deletes a loyalty rule" do
      tags "LoyaltyRules"
      security [ bearer_auth: [] ]

      response "204", "loyalty rule deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) do
          LoyaltyRule.create!(merchant: create_merchant, visits_required: 10, reward_type: "free_item",
            reward_description: "Free dessert", created_by: SecureRandom.uuid).id
        end
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          LoyaltyRule.create!(merchant: create_merchant, visits_required: 10, reward_type: "free_item",
            reward_description: "Free dessert", created_by: SecureRandom.uuid).id
        end
        run_test!
      end

      response "404", "loyalty rule not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
