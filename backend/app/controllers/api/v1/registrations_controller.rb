module Api
  module V1
    class RegistrationsController < BaseController
      # Self-registration: there is no authenticated actor yet, so the new
      # consumer is its own actor. The id is generated client-side (instead
      # of relying on the `id` column's DB-side gen_random_uuid() default)
      # so it can be reused as `created_by`, which is NOT NULL with no
      # default of its own (see db/structure.sql).
      def create
        consumer = Consumer.new(registration_params)
        consumer.id = SecureRandom.uuid
        consumer.created_by = consumer.id
        consumer.save!

        render json: {
          consumer: ConsumerBlueprint.render_as_hash(consumer),
          token: JsonWebToken.encode(sub: consumer.id)
        }, status: :created
      end

      private

      def registration_params
        params.require(:registration).permit(
          :email, :password, :password_confirmation, :first_name, :last_name, :dni, :phone
        )
      end
    end
  end
end
