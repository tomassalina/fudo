module Api
  module V1
    # ConsumerSetting only has updated_at/updated_by (see db/structure.sql),
    # no created_at/created_by/deleted_at, and destroy is a real DELETE. All
    # actions are scoped to current_consumer's own setting.
    class ConsumerSettingsController < BaseController
      before_action :authenticate_consumer!
      before_action :set_consumer_setting, only: %i[show update destroy]

      def index
        consumer_settings = paginate(current_consumer_settings)

        render json: {
          data: ConsumerSettingBlueprint.render_as_hash(consumer_settings, view: :list),
          meta: pagination_meta(consumer_settings)
        }
      end

      def show
        render json: ConsumerSettingBlueprint.render_as_hash(@consumer_setting)
      end

      # Deliberately NOT current_consumer.build_consumer_setting: has_one's
      # association builder replaces (and, per the dependent: :destroy on
      # Consumer#consumer_setting, destroys) any existing associated record
      # as part of assigning the new one — which would silently delete a
      # pre-existing setting instead of tripping the consumer_id uniqueness
      # validation below.
      def create
        consumer_setting = ConsumerSetting.new(consumer_setting_params.merge(consumer: current_consumer))
        consumer_setting.updated_by = current_consumer.id
        consumer_setting.save!

        render json: ConsumerSettingBlueprint.render_as_hash(consumer_setting), status: :created
      end

      def update
        @consumer_setting.assign_attributes(consumer_setting_params)
        @consumer_setting.updated_by = current_consumer.id
        @consumer_setting.save!

        render json: ConsumerSettingBlueprint.render_as_hash(@consumer_setting)
      end

      def destroy
        @consumer_setting.destroy!
        head :no_content
      end

      private

      # current_consumer.consumer_setting (has_one) can't be paginated
      # directly, so scope the relation the same way instead — a
      # consumer_setting belonging to another consumer must 404, not leak.
      def current_consumer_settings
        ConsumerSetting.where(consumer: current_consumer)
      end

      def set_consumer_setting
        @consumer_setting = current_consumer_settings.find(params[:id])
      end

      # consumer_id is intentionally not permitted here: ownership always
      # comes from current_consumer, never from client input.
      def consumer_setting_params
        params.require(:consumer_setting).permit(:theme, :notifications_enabled)
      end
    end
  end
end
