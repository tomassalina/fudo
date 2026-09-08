module Api
  module V1
    class SearchHistoriesController < BaseController
      before_action :set_search_history, only: %i[show update destroy]

      def index
        search_histories = paginate(filtered_search_histories)

        render json: {
          data: SearchHistoryBlueprint.render_as_hash(search_histories, view: :list),
          meta: pagination_meta(search_histories)
        }
      end

      def show
        render json: SearchHistoryBlueprint.render_as_hash(@search_history, view: :extended)
      end

      def create
        return unless (actor_id = require_actor_id!)

        search_history = SearchHistory.new(search_history_params)
        search_history.created_by = actor_id
        search_history.save!

        render json: SearchHistoryBlueprint.render_as_hash(search_history, view: :extended), status: :created
      end

      def update
        return unless (actor_id = require_actor_id!)

        @search_history.assign_attributes(search_history_params)
        @search_history.updated_by = actor_id
        @search_history.save!

        render json: SearchHistoryBlueprint.render_as_hash(@search_history, view: :extended)
      end

      def destroy
        return unless (actor_id = require_actor_id!)

        @search_history.soft_delete!(actor_id)
        head :no_content
      end

      private

      def set_search_history
        @search_history = SearchHistory.find(params[:id])
      end

      def search_history_params
        params.require(:search_history).permit(:consumer_id, :query_text, structured_output: {})
      end

      def filtered_search_histories
        scope = SearchHistory.all
        scope = scope.where(consumer_id: params[:consumer_id]) if params[:consumer_id].present?
        scope
      end
    end
  end
end
