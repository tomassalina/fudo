module Api
  module V1
    class SearchController < BaseController
      before_action :authenticate_consumer!

      def create
        query_text = params.require(:query)
        structured_output = SearchQueryParser.call(query_text)

        search_history = build_search_history(query_text, structured_output)
        search_history.save!

        merchants = paginate(Merchant.search(
          neighborhood: structured_output["neighborhood"],
          type: structured_output["type"],
          tags: structured_output["tags"],
          price_per_person: structured_output["price_per_person"]
        ))

        render json: {
          data: MerchantBlueprint.render_as_hash(merchants, view: :list),
          meta: pagination_meta(merchants)
        }
      rescue SearchQueryParser::ConfigurationError, SearchQueryParser::GeminiError => e
        Rails.logger.error("SearchQueryParser failed: #{e.class}: #{e.message}")
        render json: { error: "Search parsing is temporarily unavailable" }, status: :bad_gateway
      end

      private

      def build_search_history(query_text, structured_output)
        current_consumer.search_histories.new(
          query_text: query_text,
          structured_output: structured_output,
          created_by: current_consumer.id
        )
      end
    end
  end
end
