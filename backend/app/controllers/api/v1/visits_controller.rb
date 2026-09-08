module Api
  module V1
    class VisitsController < BaseController
      before_action :set_visit, only: %i[show update destroy]

      def index
        visits = paginate(filtered_visits)

        render json: {
          data: VisitBlueprint.render_as_hash(visits, view: :list),
          meta: pagination_meta(visits)
        }
      end

      def show
        render json: VisitBlueprint.render_as_hash(@visit, view: :extended)
      end

      def create
        return unless (actor_id = require_actor_id!)

        visit = Visit.new(visit_params)
        visit.created_by = actor_id
        visit.save!

        render json: VisitBlueprint.render_as_hash(visit, view: :extended), status: :created
      end

      def update
        return unless (actor_id = require_actor_id!)

        @visit.assign_attributes(visit_params)
        @visit.updated_by = actor_id
        @visit.save!

        render json: VisitBlueprint.render_as_hash(@visit, view: :extended)
      end

      def destroy
        return unless (actor_id = require_actor_id!)

        @visit.soft_delete!(actor_id)
        head :no_content
      end

      private

      def set_visit
        @visit = Visit.find(params[:id])
      end

      def visit_params
        params.require(:visit).permit(
          :consumer_id, :merchant_id, :amount, :reward_applied,
          :reward_description_snapshot, :visited_at
        )
      end

      def filtered_visits
        scope = Visit.all
        scope = scope.where(consumer_id: params[:consumer_id]) if params[:consumer_id].present?
        scope
      end
    end
  end
end
