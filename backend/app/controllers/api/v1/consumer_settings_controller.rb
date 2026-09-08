module Api
  module V1
    # ConsumerSetting has no created_at/created_by/deleted_at columns — only
    # updated_at/updated_by (see db/structure.sql), and destroy is a real
    # DELETE.
    class ConsumerSettingsController < BaseController
      before_action :set_consumer_setting, only: %i[show update destroy]

      def index
        consumer_settings = paginate(filtered_consumer_settings)

        render json: {
          data: ConsumerSettingBlueprint.render_as_hash(consumer_settings, view: :list),
          meta: pagination_meta(consumer_settings)
        }
      end

      def show
        render json: ConsumerSettingBlueprint.render_as_hash(@consumer_setting)
      end

      def create
        return unless (actor_id = require_actor_id!)

        consumer_setting = ConsumerSetting.new(consumer_setting_params)
        consumer_setting.updated_by = actor_id
        consumer_setting.save!

        render json: ConsumerSettingBlueprint.render_as_hash(consumer_setting), status: :created
      end

      def update
        return unless (actor_id = require_actor_id!)

        @consumer_setting.assign_attributes(consumer_setting_params)
        @consumer_setting.updated_by = actor_id
        @consumer_setting.save!

        render json: ConsumerSettingBlueprint.render_as_hash(@consumer_setting)
      end

      def destroy
        @consumer_setting.destroy!
        head :no_content
      end

      private

      def set_consumer_setting
        @consumer_setting = ConsumerSetting.find(params[:id])
      end

      def consumer_setting_params
        params.require(:consumer_setting).permit(:consumer_id, :theme, :notifications_enabled)
      end

      def filtered_consumer_settings
        scope = ConsumerSetting.all
        scope = scope.where(consumer_id: params[:consumer_id]) if params[:consumer_id].present?
        scope
      end
    end
  end
end
