module Api
  module V1
    # All actions are scoped to current_consumer: a consumer can only ever
    # see or mutate their own search history (see set_search_history / index).
    class SearchHistoriesController < BaseController
      before_action :authenticate_consumer!
      before_action :set_search_history, only: %i[show update destroy]

      def index
        search_histories = paginate(current_consumer.search_histories)

        render json: {
          data: SearchHistoryBlueprint.render_as_hash(search_histories, view: :list),
          meta: pagination_meta(search_histories)
        }
      end

      def show
        render json: SearchHistoryBlueprint.render_as_hash(@search_history, view: :extended)
      end

      def create
        search_history = current_consumer.search_histories.new(search_history_params)
        search_history.created_by = current_consumer.id
        search_history.save!

        render json: SearchHistoryBlueprint.render_as_hash(search_history, view: :extended), status: :created
      end

      def update
        @search_history.assign_attributes(search_history_params)
        @search_history.updated_by = current_consumer.id
        @search_history.save!

        render json: SearchHistoryBlueprint.render_as_hash(@search_history, view: :extended)
      end

      def destroy
        @search_history.soft_delete!(current_consumer.id)
        head :no_content
      end

      private

      # Scoped to current_consumer.search_histories, not SearchHistory.find
      # — an entry belonging to another consumer must 404, not leak.
      def set_search_history
        @search_history = current_consumer.search_histories.find(params[:id])
      end

      # consumer_id is intentionally not permitted here: ownership always
      # comes from current_consumer, never from client input.
      def search_history_params
        params.require(:search_history).permit(:query_text, structured_output: {})
      end
    end
  end
end
