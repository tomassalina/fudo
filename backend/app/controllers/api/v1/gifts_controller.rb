module Api
  module V1
    class GiftsController < BaseController
      before_action :set_gift, only: %i[show update destroy]

      def index
        gifts = paginate(filtered_gifts)

        render json: {
          data: GiftBlueprint.render_as_hash(gifts, view: :list),
          meta: pagination_meta(gifts)
        }
      end

      def show
        render json: GiftBlueprint.render_as_hash(@gift, view: :extended)
      end

      def create
        return unless (actor_id = require_actor_id!)

        gift = Gift.new(gift_params)
        gift.created_by = actor_id
        gift.save!

        render json: GiftBlueprint.render_as_hash(gift, view: :extended), status: :created
      end

      def update
        return unless (actor_id = require_actor_id!)

        @gift.assign_attributes(gift_params)
        @gift.updated_by = actor_id
        @gift.save!

        render json: GiftBlueprint.render_as_hash(@gift, view: :extended)
      end

      def destroy
        return unless (actor_id = require_actor_id!)

        @gift.soft_delete!(actor_id)
        head :no_content
      end

      private

      def set_gift
        @gift = Gift.find(params[:id])
      end

      def gift_params
        params.require(:gift).permit(
          :sender_consumer_id, :recipient_consumer_id, :type, :amount,
          :recipient_phone, :message, :expires_at, :status, :status_updated_at
        )
      end

      # Gift has no plain `consumer_id` column (it has sender_consumer_id and
      # an optional recipient_consumer_id) — filtering by `?consumer_id=` here
      # matches either side, since there's no session to scope "my gifts" to
      # sent-only or received-only.
      def filtered_gifts
        return Gift.all if params[:consumer_id].blank?

        Gift.where(sender_consumer_id: params[:consumer_id])
          .or(Gift.where(recipient_consumer_id: params[:consumer_id]))
      end
    end
  end
end
