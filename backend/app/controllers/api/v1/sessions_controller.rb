module Api
  module V1
    class SessionsController < BaseController
      # A password bcrypt is never actually compared against when there's
      # no matching digest to hash into — used to keep #create's response
      # time independent of whether the email exists (see #create).
      DUMMY_DIGEST = BCrypt::Password.create("not-a-real-password-timing-safety-only").freeze

      def create
        consumer = Consumer.find_by(email: session_params[:email])
        authenticated = authenticate(consumer)

        unless authenticated
          # Deliberately generic: does not reveal whether the email exists.
          return render json: { error: "Invalid email or password" }, status: :unauthorized
        end

        render json: {
          consumer: ConsumerBlueprint.render_as_hash(authenticated),
          token: JsonWebToken.encode(sub: authenticated.id)
        }, status: :ok
      end

      private

      def authenticate(consumer)
        if consumer
          consumer.authenticate(session_params[:password])
        else
          # Run a real (throwaway) bcrypt comparison anyway: skipping it
          # entirely when the email doesn't exist would make a non-existent
          # account measurably faster to reject than a wrong password on a
          # real one — a timing side-channel that leaks which emails are
          # registered.
          DUMMY_DIGEST.is_password?(session_params[:password])
          false
        end
      rescue BCrypt::Errors::InvalidHash
        # password_hash isn't a valid bcrypt digest (e.g. old seed/test
        # data written before has_secure_password) — treat exactly like a
        # failed authentication, never a 500.
        false
      end

      def session_params
        params.permit(:email, :password)
      end
    end
  end
end
