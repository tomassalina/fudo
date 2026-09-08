module Api
  module V1
    class MerchantsController < BaseController
      before_action :set_merchant, only: %i[show update destroy]

      def index
        return unless valid_type_filter?
        return unless valid_price_per_person_filter?

        merchants = paginate(filtered_merchants)

        render json: {
          data: MerchantBlueprint.render_as_hash(merchants, view: :list),
          meta: pagination_meta(merchants)
        }
      end

      def show
        render json: MerchantBlueprint.render_as_hash(@merchant, view: :extended)
      end

      def create
        return unless (actor_id = require_actor_id!)

        merchant = Merchant.new(merchant_params)
        merchant.created_by = actor_id
        merchant.save!

        render json: MerchantBlueprint.render_as_hash(merchant, view: :extended), status: :created
      end

      def update
        return unless (actor_id = require_actor_id!)

        @merchant.assign_attributes(merchant_params)
        @merchant.updated_by = actor_id
        @merchant.save!

        render json: MerchantBlueprint.render_as_hash(@merchant, view: :extended)
      end

      def destroy
        return unless (actor_id = require_actor_id!)

        @merchant.soft_delete!(actor_id)
        head :no_content
      end

      private

      def set_merchant
        @merchant = Merchant.find(params[:id])
      end

      def merchant_params
        params.require(:merchant).permit(
          :name, :type, :address, :country, :state, :city, :neighborhood,
          :zip_code, :latitude, :longitude, :cover_image_url,
          :whatsapp_number, :delivery_url, :price_per_person_min,
          :price_per_person_max
        )
      end

      def valid_type_filter?
        return true if params[:type].blank? || Merchant.types.key?(params[:type])

        render json: { error: "Invalid type filter value" }, status: :bad_request
        false
      end

      def valid_price_per_person_filter?
        return true if params[:price_per_person].blank?
        return true if Float(params[:price_per_person], exception: false)

        render json: { error: "Invalid price_per_person filter value" }, status: :bad_request
        false
      end

      def filtered_merchants
        scope = Merchant.all
        scope = scope.where(neighborhood: params[:neighborhood]) if params[:neighborhood].present?
        scope = scope.where(type: params[:type]) if params[:type].present?
        scope = filter_by_tags(scope)
        scope = filter_by_price_per_person(scope)
        scope
      end

      def filter_by_tags(scope)
        return scope if params[:tags].blank?

        tag_names = params[:tags].to_s.split(",").map(&:strip).reject(&:blank?)
        return scope if tag_names.empty?

        scope.joins(:tags).where(tags: { name: tag_names }).distinct
      end

      def filter_by_price_per_person(scope)
        return scope if params[:price_per_person].blank?

        scope.where(
          "price_per_person_min <= :price AND price_per_person_max >= :price",
          price: params[:price_per_person]
        )
      end
    end
  end
end
