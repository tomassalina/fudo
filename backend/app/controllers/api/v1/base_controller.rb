module Api
  module V1
    class BaseController < ApplicationController
      include Trackable

      rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :render_unprocessable_entity
      rescue_from ActionController::ParameterMissing, with: :render_bad_request
      # A Rails `enum` raises ArgumentError when assigned a value outside its
      # mapping (e.g. `type: "not_a_real_type"`), instead of producing a
      # regular validation error. Treat it the same way as any other
      # unprocessable input.
      rescue_from ArgumentError, with: :render_unprocessable_argument
      # Safety net for any filter that binds a malformed value against a
      # typed column and blows up in Postgres instead of in Ruby.
      #
      # Registered BEFORE RecordNotUnique on purpose: `rescue_from` handlers
      # are matched most-recently-registered-first (see
      # ActiveSupport::Rescuable#rescue_from — "Handlers are searched from
      # right to left... the first class for which exception.is_a?(klass)
      # holds true is the one invoked"), and RecordNotUnique < StatementInvalid,
      # so registering StatementInvalid afterwards would shadow it and turn
      # every unique-index violation into a generic 400 instead of a 409.
      rescue_from ActiveRecord::StatementInvalid, with: :render_bad_request
      # A DB-level unique index can reject an insert that model-level
      # validation let through — e.g. two concurrent requests both pass the
      # (validate-then-insert, not atomic) uniqueness check before either
      # commits, so the second INSERT still hits the index directly.
      rescue_from ActiveRecord::RecordNotUnique, with: :render_conflict

      private

      def render_not_found
        render json: { error: "Resource not found" }, status: :not_found
      end

      def render_unprocessable_entity(exception)
        render json: { errors: exception.record.errors.to_hash }, status: :unprocessable_entity
      end

      def render_unprocessable_argument(exception)
        render json: { errors: { base: [ exception.message ] } }, status: :unprocessable_entity
      end

      def render_conflict
        render json: { error: "Resource already exists" }, status: :conflict
      end

      def render_bad_request(exception)
        render json: { error: exception.message }, status: :bad_request
      end

      def paginate(scope)
        scope.page(page_param).per(per_page_param)
      end

      def pagination_meta(collection)
        {
          current_page: collection.current_page,
          total_pages: collection.total_pages,
          total_count: collection.total_count,
          per_page: collection.limit_value
        }
      end

      def page_param
        params[:page]
      end

      def per_page_param
        per = params[:per_page].to_i
        per = 20 if per <= 0
        per.clamp(1, 100)
      end
    end
  end
end
