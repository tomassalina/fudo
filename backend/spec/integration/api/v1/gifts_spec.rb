require "swagger_helper"

RSpec.describe "Gifts", type: :request do
  def build_gift(attrs = {})
    sender = attrs.delete(:sender) || create_consumer
    Gift.create!({
      sender: sender, type: "classic", amount: 5000, recipient_phone: "+5491122334455",
      expires_at: 30.days.from_now, created_by: SecureRandom.uuid
    }.merge(attrs))
  end

  gift_list_item = {
    type: :object,
    properties: {
      id: { type: :integer },
      sender_consumer_id: { type: :string },
      recipient_consumer_id: { type: :string, nullable: true },
      type: { type: :string, enum: Gift.types.keys },
      amount: { type: :string },
      status: { type: :string, enum: Gift.statuses.keys },
      expires_at: { type: :string }
    },
    required: %w[id sender_consumer_id type amount status expires_at]
  }.freeze

  gift_extended = {
    type: :object,
    properties: gift_list_item[:properties].merge(
      recipient_phone: { type: :string },
      message: { type: :string, nullable: true },
      status_updated_at: { type: :string, nullable: true },
      created_at: { type: :string },
      updated_at: { type: :string }
    ),
    required: gift_list_item[:required] + %w[recipient_phone created_at updated_at]
  }.freeze

  path "/api/v1/gifts" do
    get "Lists gifts where the authenticated consumer is sender or recipient" do
      tags "Gifts"
      security [ bearer_auth: [] ]
      produces "application/json"

      response "200", "gifts found" do
        schema type: :object,
          properties: {
            data: { type: :array, items: gift_list_item },
            meta: { "$ref" => "#/components/schemas/pagination_meta" }
          },
          required: %w[data meta]

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        before { build_gift(sender: consumer) }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        run_test!
      end
    end

    post "Creates a gift" do
      tags "Gifts"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "The authenticated consumer is always the sender. status is never client-settable " \
        "— every new gift starts pending."
      parameter name: :gift, in: :body, schema: {
        type: :object,
        properties: {
          gift: {
            type: :object,
            properties: {
              type: { type: :string, enum: Gift.types.keys },
              amount: { type: :number },
              recipient_phone: { type: :string },
              recipient_consumer_id: { type: :string },
              message: { type: :string },
              expires_at: { type: :string }
            },
            required: %w[type amount recipient_phone expires_at]
          }
        },
        required: %w[gift]
      }

      response "201", "gift created" do
        schema gift_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:gift) { { gift: { type: "gold", amount: 10_000, recipient_phone: "+5491100000000", expires_at: 10.days.from_now.iso8601 } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:gift) { { gift: { type: "gold", amount: 10_000, recipient_phone: "+5491100000000", expires_at: 10.days.from_now.iso8601 } } }
        run_test!
      end

      response "422", "validation failed" do
        schema "$ref" => "#/components/schemas/validation_errors"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:gift) { { gift: { type: "gold", amount: 10_000, recipient_phone: nil, expires_at: 10.days.from_now.iso8601 } } }
        run_test!
      end
    end
  end

  path "/api/v1/gifts/{id}" do
    parameter name: :id, in: :path, schema: { type: :integer }

    get "Retrieves a gift" do
      tags "Gifts"
      security [ bearer_auth: [] ]
      produces "application/json"
      description "Scoped to gifts where the authenticated consumer is sender or recipient — otherwise 404."

      response "200", "gift found" do
        schema gift_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { build_gift(sender: consumer).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { build_gift.id }
        run_test!
      end

      response "404", "gift not found (or the consumer has no part in it)" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end
    end

    patch "Updates a gift" do
      tags "Gifts"
      security [ bearer_auth: [] ]
      consumes "application/json"
      produces "application/json"
      description "Gifts are immutable except for one case: the sender cancelling their own still-pending " \
        "gift by setting status to \"cancelled\". Marking a gift redeemed is NOT a consumer-facing action."
      parameter name: :gift, in: :body, schema: {
        type: :object,
        properties: {
          gift: {
            type: :object,
            properties: { status: { type: :string, enum: %w[cancelled] } },
            required: %w[status]
          }
        },
        required: %w[gift]
      }

      response "200", "gift cancelled by its sender" do
        schema gift_extended

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { build_gift(sender: consumer).id }
        let(:gift) { { gift: { status: "cancelled" } } }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { build_gift.id }
        let(:gift) { { gift: { status: "cancelled" } } }
        run_test!
      end

      response "403", "the recipient (not the sender) tried to update the gift" do
        schema "$ref" => "#/components/schemas/error"

        let(:sender) { create_consumer }
        let(:recipient) { create_consumer }
        let(:Authorization) { auth_headers_for(recipient)["Authorization"] }
        let(:id) { build_gift(sender: sender, recipient_consumer_id: recipient.id).id }
        let(:gift) { { gift: { status: "cancelled" } } }
        run_test!
      end

      response "404", "gift not found (or the consumer has no part in it)" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        let(:gift) { { gift: { status: "cancelled" } } }
        run_test!
      end

      response "422", "gift can no longer be cancelled (already redeemed/expired/cancelled)" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { build_gift(sender: consumer, status: "redeemed", status_updated_at: Time.current).id }
        let(:gift) { { gift: { status: "cancelled" } } }
        run_test!
      end
    end

    delete "Soft-deletes a gift" do
      tags "Gifts"
      security [ bearer_auth: [] ]
      description "Only the sender may delete their own gift, and only while it is still pending — " \
        "deleting hides the gift from BOTH sender and recipient (Gift's soft-delete scope is global), " \
        "so this is deliberately as restricted as #update's cancel path."

      response "204", "gift deleted" do
        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { build_gift(sender: consumer).id }
        run_test!
      end

      response "401", "not authenticated" do
        schema "$ref" => "#/components/schemas/error"

        let(:Authorization) { nil }
        let(:id) { build_gift.id }
        run_test!
      end

      response "403", "the recipient (not the sender) tried to delete the gift" do
        schema "$ref" => "#/components/schemas/error"

        let(:sender) { create_consumer }
        let(:recipient) { create_consumer }
        let(:Authorization) { auth_headers_for(recipient)["Authorization"] }
        let(:id) { build_gift(sender: sender, recipient_consumer_id: recipient.id).id }
        run_test!
      end

      response "404", "gift not found (or the consumer has no part in it)" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { 999_999 }
        run_test!
      end

      response "422", "gift is no longer pending and can no longer be deleted" do
        schema "$ref" => "#/components/schemas/error"

        let(:consumer) { create_consumer }
        let(:Authorization) { auth_headers_for(consumer)["Authorization"] }
        let(:id) { build_gift(sender: consumer, status: "redeemed", status_updated_at: Time.current).id }
        run_test!
      end
    end
  end
end
