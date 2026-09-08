module Api
  module V1
    # All actions are scoped to current_consumer being either the sender or
    # the recipient of the gift (see accessible_gifts / set_gift).
    class GiftsController < BaseController
      before_action :authenticate_consumer!
      before_action :set_gift, only: %i[show update destroy]

      def index
        gifts = paginate(accessible_gifts)

        render json: {
          data: GiftBlueprint.render_as_hash(gifts, view: :list),
          meta: pagination_meta(gifts)
        }
      end

      def show
        render json: GiftBlueprint.render_as_hash(@gift, view: :extended)
      end

      # current_consumer is always the sender: a consumer can only send
      # gifts as themselves, never on another consumer's behalf. status is
      # intentionally not accepted here either — every new gift starts
      # `pending` (the column's DB default), never client-chosen.
      def create
        gift = current_consumer.sent_gifts.new(gift_create_params)
        gift.created_by = current_consumer.id
        gift.save!

        render json: GiftBlueprint.render_as_hash(gift, view: :extended), status: :created
      end

      # Gifts are immutable once created — amount/type/sender/recipient can
      # never be changed via the API — with exactly one exception: the
      # SENDER can cancel their own still-`pending` gift. Nothing else is
      # mutable here. In particular, marking a gift `redeemed` is NOT a
      # consumer-facing action: it belongs to a staff/merchant redemption
      # flow that doesn't exist yet (out of scope for this auth stage).
      def update
        unless @gift.sender_consumer_id == current_consumer.id
          return render json: { error: "Only the sender can update this gift" }, status: :forbidden
        end

        unless gift_update_params[:status] == "cancelled"
          return render json: { error: "Gifts can only be updated to cancel a pending gift" }, status: :unprocessable_entity
        end

        unless @gift.pending?
          return render json: { error: "Only a pending gift can be cancelled" }, status: :unprocessable_entity
        end

        @gift.status = "cancelled"
        @gift.status_updated_at = Time.current
        @gift.updated_by = current_consumer.id
        @gift.save!

        render json: GiftBlueprint.render_as_hash(@gift, view: :extended)
      end

      def destroy
        @gift.soft_delete!(current_consumer.id)
        head :no_content
      end

      private

      # Scoped to gifts where current_consumer is sender OR recipient, not
      # Gift.find — a gift the consumer has no part in must 404.
      def set_gift
        @gift = accessible_gifts.find(params[:id])
      end

      def accessible_gifts
        Gift.where(sender_consumer_id: current_consumer.id)
          .or(Gift.where(recipient_consumer_id: current_consumer.id))
      end

      # sender_consumer_id is intentionally not permitted here: the sender
      # always comes from current_consumer, never from client input. status
      # is not accepted at creation either (see #create) — it always starts
      # `pending`.
      def gift_create_params
        params.require(:gift).permit(:recipient_consumer_id, :type, :amount, :recipient_phone, :message, :expires_at)
      end

      # The only field #update ever looks at — see the authorization/state
      # guards in #update for what values of `status` are actually allowed.
      def gift_update_params
        params.require(:gift).permit(:status)
      end
    end
  end
end
