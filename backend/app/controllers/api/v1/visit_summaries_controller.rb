module Api
  module V1
    # VisitSummary has no audit columns (see db/structure.sql) and no soft
    # delete, so destroy is a real DELETE. All actions are scoped to
    # current_consumer's own visit summaries.
    class VisitSummariesController < BaseController
      before_action :authenticate_consumer!
      before_action :set_visit_summary, only: %i[show update destroy]

      def index
        visit_summaries = paginate(current_consumer.visit_summaries)

        render json: {
          data: VisitSummaryBlueprint.render_as_hash(visit_summaries, view: :list),
          meta: pagination_meta(visit_summaries)
        }
      end

      def show
        render json: VisitSummaryBlueprint.render_as_hash(@visit_summary)
      end

      def create
        visit_summary = current_consumer.visit_summaries.new(visit_summary_params)
        assign_computed_progress(visit_summary)
        visit_summary.save!

        render json: VisitSummaryBlueprint.render_as_hash(visit_summary), status: :created
      end

      def update
        @visit_summary.assign_attributes(visit_summary_params)
        assign_computed_progress(@visit_summary)
        @visit_summary.save!

        render json: VisitSummaryBlueprint.render_as_hash(@visit_summary)
      end

      def destroy
        @visit_summary.destroy!
        head :no_content
      end

      private

      # Scoped to current_consumer.visit_summaries, not VisitSummary.find —
      # a summary belonging to another consumer must 404, not leak.
      def set_visit_summary
        @visit_summary = current_consumer.visit_summaries.find(params[:id])
      end

      # consumer_id is intentionally not permitted here: ownership always
      # comes from current_consumer, never from client input.
      #
      # count/current_tier are also intentionally not permitted — they used
      # to be, with almost no validation (current_tier was a free-text
      # column, count only checked >= 0), which let a consumer forge any
      # loyalty tier/count via a bare PATCH, unrelated to their real Visit
      # rows (e.g. `{ current_tier: "platinum", count: 9999 }`). Both are
      # now computed from real data instead (see #assign_computed_progress)
      # — merchant_id/last_visit_at stay client-settable, same as before.
      def visit_summary_params
        params.require(:visit_summary).permit(:merchant_id, :last_visit_at)
      end

      # Derives count/current_tier from the consumer's real, non-deleted
      # Visit rows at this merchant and the merchant's real loyalty_rules —
      # the same algorithm db/seeds.rb uses to build demo data (see
      # VisitSummary.tier_for) — instead of trusting whatever the client
      # sent. Runs on both create and update, keyed off whatever merchant_id
      # ends up set (so changing merchant_id on update recomputes progress
      # for the new merchant rather than carrying over the old one's).
      def assign_computed_progress(visit_summary)
        merchant = visit_summary.merchant
        count = merchant ? current_consumer.visits.where(merchant_id: merchant.id).count : 0

        visit_summary.count = count
        visit_summary.current_tier = merchant ? VisitSummary.tier_for(merchant, count) : nil
      end
    end
  end
end
