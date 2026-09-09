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
        visit_summary.save!

        render json: VisitSummaryBlueprint.render_as_hash(visit_summary), status: :created
      end

      def update
        @visit_summary.update!(visit_summary_params)

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
      def visit_summary_params
        params.require(:visit_summary).permit(:merchant_id, :count, :current_tier, :last_visit_at)
      end
    end
  end
end
