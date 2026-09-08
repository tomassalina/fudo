module Api
  module V1
    class SearchController < BaseController
      def create
        return unless (actor_id = require_actor_id!)

        query_text = params.require(:query)
        # Look up the consumer BEFORE calling Gemini: the API call has a real
        # dollar cost per request, so a request with a bad/missing
        # consumer_id should fail fast instead of burning paid quota on a
        # search that can never be persisted anyway.
        consumer = Consumer.find(params[:consumer_id])
        structured_output = SearchQueryParser.call(query_text)

        search_history = build_search_history(query_text, structured_output, consumer.id, actor_id)
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

      def build_search_history(query_text, structured_output, consumer_id, actor_id)
        SearchHistory.new(
          consumer_id: consumer_id,
          query_text: query_text,
          structured_output: structured_output,
          created_by: actor_id
        )
      end
    end
  end
end
