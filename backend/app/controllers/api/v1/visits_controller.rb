module Api
  module V1
    # All actions are scoped to current_consumer: a consumer can only ever
    # see or mutate their own visits (see set_visit / index).
    class VisitsController < BaseController
      before_action :authenticate_consumer!
      before_action :set_visit, only: %i[show update destroy]

      def index
        visits = paginate(current_consumer.visits)

        render json: {
          data: VisitBlueprint.render_as_hash(visits, view: :list),
          meta: pagination_meta(visits)
        }
      end

      def show
        render json: VisitBlueprint.render_as_hash(@visit, view: :extended)
      end

      def create
        visit = current_consumer.visits.new(visit_params)
        visit.created_by = current_consumer.id
        # reward_applied always starts false — never client-settable (see
        # visit_params) — a consumer must not be able to self-grant a
        # loyalty reward on their own visit.
        visit.reward_applied = false
        visit.save!

        render json: VisitBlueprint.render_as_hash(visit, view: :extended), status: :created
      end

      def update
        @visit.assign_attributes(update_visit_params)
        @visit.updated_by = current_consumer.id
        @visit.save!

        render json: VisitBlueprint.render_as_hash(@visit, view: :extended)
      end

      def destroy
        @visit.soft_delete!(current_consumer.id)
        head :no_content
      end

      private

      # Scoped to current_consumer.visits, not Visit.find — a visit
      # belonging to another consumer must 404, not leak its existence.
      def set_visit
        @visit = current_consumer.visits.find(params[:id])
      end

      # consumer_id is intentionally not permitted here: ownership always
      # comes from current_consumer, never from client input.
      #
      # reward_applied/reward_description_snapshot are also excluded on
      # purpose (both create and update) — a consumer must never be able to
      # grant themselves a loyalty reward by just setting it on the
      # request. There's no staff/merchant flow yet to apply rewards
      # server-side, so for now reward_applied simply stays false forever
      # via the API (see #create) — accepted MVP limitation, not solved
      # here.
      #
      # `amount` is still client-supplied for the same reason: without a
      # merchant/staff-side flow to record the real charged amount, there's
      # no better source for it yet. Also an accepted MVP limitation.
      def visit_params
        params.require(:visit).permit(:merchant_id, :amount, :visited_at)
      end

      # merchant_id/amount are deliberately NOT permitted here, unlike
      # visit_params above. Trusting the client for `amount` at CREATE time
      # is an accepted MVP limitation (see visit_params) because there's no
      # better source yet — but allowing UPDATE to touch merchant_id/amount
      # is strictly worse: it would let a consumer silently rewrite which
      # merchant a past visit belongs to, or the amount charged, after the
      # fact. A visit's merchant and charged amount are immutable once
      # recorded; visited_at is the only field a consumer can still correct
      # post-creation.
      def update_visit_params
        params.require(:visit).permit(:visited_at)
      end
    end
  end
end
