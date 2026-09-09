require "swagger_helper"

RSpec.describe "MenuItems", type: :request do
  menu_item_list_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      merchant_id: { type: :integer },
      name: { type: :string },
      price: { type: :string },
      currency: { type: :string, enum: MenuItem.currencies.keys },
      section: { type: :string, nullable: true },
      image_url: { type: :string, nullable: true },
      active: { type: :boolean }
    },
    required: %w[id merchant_id name price currency active]
  }.freeze

  menu_item_extended = {
    type: :object,
    properties: menu_item_list_item[:properties].merge(
      description: { type: :string, nullable: true },
      created_at: { type: :string },
      updated_at: { type: :string },
      tags: { type: :array, items: { type: :string } }
    ),
    required: menu_item_list_item[:required] + %w[created_at updated_at tags]
  }.freeze

  path "/api/v1/menu_items" do
    get "Lists menu items" do
      tags "MenuItems"
      produces "application/json"
      description "Public — no authentication required."
      parameter name: :merchant_id, in: :query, schema: { type: :integer }, required: false,
        description: "Filter by merchant"
      parameter name: :page, in: :query, schema: { type: :integer }, required: false
      parameter name: :per_page, in: :query, schema: { type: :integer }, required: false

      response "200", "menu items found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: menu_item_list_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        let(:merchant) { create_merchant }
        before { MenuItem.create!(merchant: merchant, name: "Milanesa", price: 5000, currency: "ars", created_by: SecureRandom.uuid) }
        run_test!
      end
    end

    post "Creates a menu item" do
      tags "MenuItems"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :menu_item, in: :body, schema: {
        type: :object,
        properties: {
          menu_item: {
            type: :object,
            properties: {
              merchant_id: { type: :integer },
              name: { type: :string },
              description: { type: :string },
              price: { type: :number },
              currency: { type: :string, enum: MenuItem.currencies.keys },
              section: { type: :string },
              image_url: { type: :string },
              active: { type: :boolean }
            },
            required: %w[merchant_id name price currency]
          }
        },
        required: %w[menu_item]
      }

      response "201", "menu item created" do
        schema menu_item_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:menu_item) { { menu_item: { merchant_id: merchant.id, name: "Milanesa", price: 5000, currency: "ars" } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:merchant) { create_merchant }
        let(:menu_item) { { menu_item: { merchant_id: merchant.id, name: "Milanesa", price: 5000, currency: "ars" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:merchant) { create_merchant }
        let(:menu_item) { { menu_item: { merchant_id: merchant.id, name: "", price: 5000, currency: "ars" } } }
        run_test!
      end
    end
  end

  path "/api/v1/menu_items/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a menu item" do
      tags "MenuItems"
      produces "application/json"
      description "Public — no authentication required."

      response "200", "menu item found" do
        schema menu_item_extended

        let(:id) { MenuItem.create!(merchant: create_merchant, name: "Milanesa", price: 5000, currency: "ars", created_by: SecureRandom.uuid).id }
        run_test!
      end

      response "404", "menu item not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a menu item" do
      tags "MenuItems"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :menu_item, in: :body, schema: {
        type: :object,
        properties: {
          menu_item: {
            type: :object,
            properties: {
              name: { type: :string },
              description: { type: :string },
              price: { type: :number },
              currency: { type: :string, enum: MenuItem.currencies.keys },
              active: { type: :boolean }
            }
          }
        }
      }

      response "200", "menu item updated" do
        schema menu_item_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { MenuItem.create!(merchant: create_merchant, name: "Milanesa", price: 5000, currency: "ars", created_by: SecureRandom.uuid).id }
        let(:menu_item) { { menu_item: { active: false } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { MenuItem.create!(merchant: create_merchant, name: "Milanesa", price: 5000, currency: "ars", created_by: SecureRandom.uuid).id }
        let(:menu_item) { { menu_item: { active: false } } }
        run_test!
      end

      response "404", "menu item not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:menu_item) { { menu_item: { active: false } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { MenuItem.create!(merchant: create_merchant, name: "Milanesa", price: 5000, currency: "ars", created_by: SecureRandom.uuid).id }
        let(:menu_item) { { menu_item: { price: -1 } } }
        run_test!
      end
    end

    delete "Soft-deletes a menu item" do
      tags "MenuItems"
      security [ bearer_auth: [] ]

      response "204", "menu item deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { MenuItem.create!(merchant: create_merchant, name: "Milanesa", price: 5000, currency: "ars", created_by: SecureRandom.uuid).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { MenuItem.create!(merchant: create_merchant, name: "Milanesa", price: 5000, currency: "ars", created_by: SecureRandom.uuid).id }
        run_test!
      end

      response "404", "menu item not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
