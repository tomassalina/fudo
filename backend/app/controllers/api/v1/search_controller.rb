module Api
  module V1
    # Public, unauthenticated on purpose — product rule (confirmed live by
    # the product owner): AI search and /buscar (browsing/filtering/search)
    # are free to use with no account; only profile, gift purchase, and
    # visit-history/loyalty data require a logged-in consumer. Do NOT add
    # `authenticate_consumer!` back here. When a valid bearer token IS
    # present (an already-logged-in consumer using search), the query is
    # still attributed and saved to that consumer's search history, same as
    # before — see build_search_history below. For an anonymous caller
    # (current_consumer nil) no SearchHistory row is written at all, since
    # search_history.consumer_id is NOT NULL (belongs_to :consumer,
    # required) and there is no "anonymous" consumer to attribute it to.
    class SearchController < BaseController
      def create
        query_text = params.require(:query)
        structured_output = SearchQueryParser.call(query_text)

        build_search_history(query_text, structured_output)&.save!

        merchants = paginate(Merchant.search(
          neighborhood: structured_output["neighborhood"],
          type: structured_output["type"],
          tags: structured_output["tags"],
          price_per_person: structured_output["price_per_person"]
        ))

        render json: {
          data: MerchantBlueprint.render_as_hash(merchants, view: :list),
          meta: pagination_meta(merchants),
          # The filters Gemini actually derived (same shape SearchQueryParser
          # returns and SearchHistory#structured_output persists) — without
          # this, a client has no way to know which neighborhood/type/tags/
          # price this response's merchants were filtered by, so it can't
          # build a shareable "/buscar?type=...&hood=..." URL out of a
          # natural-language search (see web/lib/api/search.ts).
          filters: structured_output
        }
      rescue SearchQueryParser::ConfigurationError, SearchQueryParser::GeminiError => e
        Rails.logger.error("SearchQueryParser failed: #{e.class}: #{e.message}")
        render json: { error: "Search parsing is temporarily unavailable" }, status: :bad_gateway
      end

      private

      def build_search_history(query_text, structured_output)
        return nil unless current_consumer

        current_consumer.search_histories.new(
          query_text: query_text,
          structured_output: structured_output,
          created_by: current_consumer.id
        )
      end
    end
  end
end
