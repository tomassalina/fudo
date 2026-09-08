module Api
  module V1
    # VisitSummary has no audit columns (see db/structure.sql) and no soft
    # delete, so this controller never touches X-Actor-Id and destroy is a
    # real DELETE.
    class VisitSummariesController < BaseController
      before_action :set_visit_summary, only: %i[show update destroy]

      def index
        visit_summaries = paginate(filtered_visit_summaries)

        render json: {
          data: VisitSummaryBlueprint.render_as_hash(visit_summaries, view: :list),
          meta: pagination_meta(visit_summaries)
        }
      end

      def show
        render json: VisitSummaryBlueprint.render_as_hash(@visit_summary)
      end

      def create
        visit_summary = VisitSummary.new(visit_summary_params)
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

      def set_visit_summary
        @visit_summary = VisitSummary.find(params[:id])
      end

      def visit_summary_params
        params.require(:visit_summary).permit(:consumer_id, :merchant_id, :count, :current_tier, :last_visit_at)
      end

      def filtered_visit_summaries
        scope = VisitSummary.all
        scope = scope.where(consumer_id: params[:consumer_id]) if params[:consumer_id].present?
        scope
      end
    end
  end
end
