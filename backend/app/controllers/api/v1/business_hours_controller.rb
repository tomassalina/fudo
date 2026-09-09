module Api
  module V1
    # BusinessHour has no audit columns (see db/structure.sql) and no soft
    # delete, so there's nothing to stamp here — but writes still require
    # authentication like the rest of the catalog.
    #
    # ACCEPTED LIMITATION: see the comment atop MerchantsController — any
    # authenticated consumer can write business hours for any merchant, no
    # staff/ownership model exists yet.
    class BusinessHoursController < BaseController
      before_action :authenticate_consumer!, except: %i[index show]
      before_action :set_business_hour, only: %i[show update destroy]

      def index
        business_hours = paginate(filtered_business_hours)

        render json: {
          data: BusinessHourBlueprint.render_as_hash(business_hours, view: :list),
          meta: pagination_meta(business_hours)
        }
      end

      def show
        render json: BusinessHourBlueprint.render_as_hash(@business_hour)
      end

      def create
        business_hour = BusinessHour.new(business_hour_params)
        business_hour.save!

        render json: BusinessHourBlueprint.render_as_hash(business_hour), status: :created
      end

      def update
        @business_hour.update!(business_hour_params)

        render json: BusinessHourBlueprint.render_as_hash(@business_hour)
      end

      def destroy
        @business_hour.destroy!
        head :no_content
      end

      private

      def set_business_hour
        @business_hour = BusinessHour.find(params[:id])
      end

      def business_hour_params
        params.require(:business_hour).permit(:merchant_id, :day_of_week, :opens_at, :closes_at, :closed)
      end

      def filtered_business_hours
        scope = BusinessHour.all
        scope = scope.where(merchant_id: params[:merchant_id]) if params[:merchant_id].present?
        scope
      end
    end
  end
end
