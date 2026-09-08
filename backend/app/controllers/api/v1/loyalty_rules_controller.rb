module Api
  module V1
    class LoyaltyRulesController < BaseController
      before_action :set_loyalty_rule, only: %i[show update destroy]

      def index
        loyalty_rules = paginate(filtered_loyalty_rules)

        render json: {
          data: LoyaltyRuleBlueprint.render_as_hash(loyalty_rules, view: :list),
          meta: pagination_meta(loyalty_rules)
        }
      end

      def show
        render json: LoyaltyRuleBlueprint.render_as_hash(@loyalty_rule, view: :extended)
      end

      def create
        return unless (actor_id = require_actor_id!)

        loyalty_rule = LoyaltyRule.new(loyalty_rule_params)
        loyalty_rule.created_by = actor_id
        loyalty_rule.save!

        render json: LoyaltyRuleBlueprint.render_as_hash(loyalty_rule, view: :extended), status: :created
      end

      def update
        return unless (actor_id = require_actor_id!)

        @loyalty_rule.assign_attributes(loyalty_rule_params)
        @loyalty_rule.updated_by = actor_id
        @loyalty_rule.save!

        render json: LoyaltyRuleBlueprint.render_as_hash(@loyalty_rule, view: :extended)
      end

      def destroy
        return unless (actor_id = require_actor_id!)

        @loyalty_rule.soft_delete!(actor_id)
        head :no_content
      end

      private

      def set_loyalty_rule
        @loyalty_rule = LoyaltyRule.find(params[:id])
      end

      def loyalty_rule_params
        params.require(:loyalty_rule).permit(
          :merchant_id, :visits_required, :reward_type, :reward_description, :is_permanent
        )
      end

      def filtered_loyalty_rules
        scope = LoyaltyRule.all
        scope = scope.where(merchant_id: params[:merchant_id]) if params[:merchant_id].present?
        scope
      end
    end
  end
end
