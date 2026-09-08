require "swagger_helper"

RSpec.describe "ConsumerSettings", type: :request do
  consumer_setting_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      consumer_id: { type: :string },
      theme: { type: :string, enum: ConsumerSetting.themes.keys },
      notifications_enabled: { type: :boolean },
      updated_at: { type: :string }
    },
    required: %w[id consumer_id theme notifications_enabled updated_at]
  }.freeze

  path "/api/v1/consumer_settings" do
    get "Lists the authenticated consumer's own setting" do
      tags "ConsumerSettings"
      security [ bearer_auth: [] ]
      produces "application/json"

      response "200", "consumer settings found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: consumer_setting_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        before { ConsumerSetting.create!(consumer: consumer, theme: "dark", updated_by: consumer.id) }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        run_test!
      end
    end

    post "Creates the authenticated consumer's setting" do
      tags "ConsumerSettings"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "consumer_id always comes from the authenticated consumer. Each consumer may have at " \
        "most one setting (consumer_id is unique)."
      parameter name: :consumer_setting, in: :body, schema: {
        type: :object,
        properties: {
          consumer_setting: {
            type: :object,
            properties: {
              theme: { type: :string, enum: ConsumerSetting.themes.keys },
              notifications_enabled: { type: :boolean }
            }
          }
        },
        required: %w[consumer_setting]
      }

      response "201", "consumer setting created" do
        schema consumer_setting_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:consumer_setting) { { consumer_setting: { theme: "dark", notifications_enabled: false } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:consumer_setting) { { consumer_setting: { theme: "dark" } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        before { ConsumerSetting.create!(consumer: consumer, theme: "dark", updated_by: consumer.id) }
        let(:consumer_setting) { { consumer_setting: { theme: "light" } } }
        run_test!
      end
    end
  end

  path "/api/v1/consumer_settings/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a consumer setting" do
      tags "ConsumerSettings"
      security [ bearer_auth: [] ]
      produces "application/json"
      description "Scoped to the authenticated consumer's own setting — another consumer's setting 404s."

      response "200", "consumer setting found" do
        schema consumer_setting_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { ConsumerSetting.create!(consumer: consumer, theme: "dark", updated_by: consumer.id).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          ConsumerSetting.create!(consumer: consumer, theme: "dark", updated_by: consumer.id).id
        end
        run_test!
      end

      response "404", "consumer setting not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a consumer setting" do
      tags "ConsumerSettings"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      parameter name: :consumer_setting, in: :body, schema: {
        type: :object,
        properties: {
          consumer_setting: {
            type: :object,
            properties: {
              theme: { type: :string, enum: ConsumerSetting.themes.keys },
              notifications_enabled: { type: :boolean }
            }
          }
        }
      }

      response "200", "consumer setting updated" do
        schema consumer_setting_item

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { ConsumerSetting.create!(consumer: consumer, theme: "dark", updated_by: consumer.id).id }
        let(:consumer_setting) { { consumer_setting: { theme: "light" } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          ConsumerSetting.create!(consumer: consumer, theme: "dark", updated_by: consumer.id).id
        end
        let(:consumer_setting) { { consumer_setting: { theme: "light" } } }
        run_test!
      end

      response "404", "consumer setting not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:consumer_setting) { { consumer_setting: { theme: "light" } } }
        run_test!
      end
    end

    delete "Deletes a consumer setting" do
      tags "ConsumerSettings"
      security [ bearer_auth: [] ]
      description "Hard delete — ConsumerSetting has no soft-delete column."

      response "204", "consumer setting deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { ConsumerSetting.create!(consumer: consumer, theme: "dark", updated_by: consumer.id).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) do
          consumer = create_consumer
          ConsumerSetting.create!(consumer: consumer, theme: "dark", updated_by: consumer.id).id
        end
        run_test!
      end

      response "404", "consumer setting not found" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end
  end
end
