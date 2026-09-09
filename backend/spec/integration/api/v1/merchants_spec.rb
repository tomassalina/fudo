require "swagger_helper"

RSpec.describe "Merchants", type: :request do
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

  business_hour_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      merchant_id: { type: :integer },
      day_of_week: { type: :string, enum: BusinessHour.day_of_weeks.keys },
      opens_at: { type: :string, nullable: true },
      closes_at: { type: :string, nullable: true },
      closed: { type: :boolean }
    },
    required: %w[id merchant_id day_of_week closed]
  }.freeze

  merchant_extended = {
    type: :object,
    properties: merchant_list_item[:properties].merge(
      address: { type: :string },
      country: { type: :string },
      state: { type: :string },
      zip_code: { type: :string, nullable: true },
      whatsapp_number: { type: :string, nullable: true },
      delivery_url: { type: :string, nullable: true },
      created_at: { type: :string },
      updated_at: { type: :string },
      tags: { type: :array, items: { type: :string } },
      business_hours: { type: :array, items: business_hour_item }
    ),
    required: merchant_list_item[:required] + %w[address country state created_at updated_at tags business_hours]
  }.freeze

  merchant_input_properties = {
    name: { type: :string },
    type: { type: :string, enum: Merchant.types.keys },
    address: { type: :string },
    country: { type: :string },
    state: { type: :string },
    city: { type: :string },
    neighborhood: { type: :string },
    zip_code: { type: :string },
    latitude: { type: :number },
    longitude: { type: :number },
    cover_image_url: { type: :string },
    whatsapp_number: { type: :string },
    delivery_url: { type: :string },
    price_per_person_min: { type: :number },
    price_per_person_max: { type: :number }
  }.freeze

  path "/api/v1/merchants" do
    get "Lists merchants" do
      tags "Merchants"
      produces "application/json"
      description "Public catalog listing — no authentication required."
      parameter name: :neighborhood, in: :query, schema: { type: :string }, required: false,
        description: "Exact neighborhood match"
      parameter name: :type, in: :query, schema: { type: :string, enum: Merchant.types.keys }, required: false,
        description: "Merchant type filter"
      parameter name: :tags, in: :query, schema: { type: :string }, required: false,
        description: "Comma-separated tag names, e.g. \"vegano,con_delivery\""
      parameter name: :price_per_person, in: :query, schema: { type: :number }, required: false,
        description: "Matches merchants whose price_per_person_min/max range includes this value"
      parameter name: :page, in: :query, schema: { type: :integer }, required: false
      parameter name: :per_page, in: :query, schema: { type: :integer }, required: false

      response "200", "merchants found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: merchant_list_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        before { create_merchant(neighborhood: "Palermo") }
        run_test!
      end

      response "400", "invalid type filter" do
        schema "$ref" => "#/components/schemas/error"

        let(:type) { "not_a_real_type" }
        run_test!
      end

      response "400", "invalid price_per_person filter" do
        schema "$ref" => "#/components/schemas/error"

        let(:price_per_person) { "not-a-number" }
        run_test!
      end
    end

    post "Creates a merchant" do
      tags "Merchants"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "Any authenticated consumer may create a merchant — there is no staff/ownership " \
        "model yet (accepted MVP limitation)."
      parameter name: :merchant, in: :body, schema: {
        type: :object,
        properties: {
          merchant: {
            type: :object,
            properties: merchant_input_properties,
            required: %w[name type address country state city latitude longitude]
          }
        },
        required: %w[merchant]
      }

      response "201", "merchant created" do
        schema merchant_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) do
          {
            merchant: {
              name: "New Merchant", type: "restaurant", address: "Av. Test 1", country: "Argentina",
              state: "Buenos Aires", city: "CABA", latitude: -34.6, longitude: -58.4
            }
          }
        end
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:merchant) { { merchant: { name: "New Merchant" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { { merchant: { name: "" } } }
        run_test!
      end
    end
  end

  path "/api/v1/merchants/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a merchant" do
      tags "Merchants"
      produces "application/json"
      description "Public — no authentication required. Includes tags and business hours."

      response "200", "merchant found" do
        schema merchant_extended

        let(:id) { create_merchant.id }
        run_test!
      end

      response "404", "merchant not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a merchant" do
      tags "Merchants"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "Any authenticated consumer may update any merchant — accepted MVP limitation (see #create)."
      parameter name: :merchant, in: :body, schema: {
        type: :object,
        properties: {
          merchant: { type: :object, properties: merchant_input_properties }
        }
      }

      response "200", "merchant updated" do
        schema merchant_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { create_merchant.id }
        let(:merchant) { { merchant: { name: "Updated name" } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { create_merchant.id }
        let(:merchant) { { merchant: { name: "Updated name" } } }
        run_test!
      end

      response "404", "merchant not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:merchant) { { merchant: { name: "Updated name" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { create_merchant.id }
        let(:merchant) { { merchant: { name: "" } } }
        run_test!
      end
    end

    delete "Soft-deletes a merchant" do
      tags "Merchants"
      security [ bearer_auth: [] ]

      response "204", "merchant deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { create_merchant.id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { create_merchant.id }
        run_test!
      end

      response "404", "merchant not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
