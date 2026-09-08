module Api
  module V1
    # All actions are scoped to current_consumer: a consumer can only ever
    # see or mutate their own favorites (see set_favorite / index).
    class FavoritesController < BaseController
      before_action :authenticate_consumer!
      before_action :set_favorite, only: %i[show update destroy]

      def index
        favorites = paginate(current_consumer.favorites)

        render json: {
          data: FavoriteBlueprint.render_as_hash(favorites, view: :list),
          meta: pagination_meta(favorites)
        }
      end

      def show
        render json: FavoriteBlueprint.render_as_hash(@favorite)
      end

      # The DB's unique index on (consumer_id, merchant_id) is NOT partial
      # (see db/structure.sql) — it applies to every row regardless of
      # deleted_at. So unfavoriting (soft delete) and then re-favoriting the
      # same merchant would otherwise always hit that index directly and
      # 409 forever, even though the default_scope hides the soft-deleted
      # row from view (and from the uniqueness *validation*, which only
      # sees non-deleted rows and would happily let a plain INSERT through
      # right into the index conflict). Revive the existing row instead of
      # inserting a new one whenever this exact (consumer, merchant) pair
      # was previously soft-deleted.
      def create
        favorite = current_consumer.favorites.new(favorite_params)
        favorite.created_by = current_consumer.id

        existing = Favorite.unscoped.find_by(consumer_id: current_consumer.id, merchant_id: favorite.merchant_id)

        if existing&.deleted_at
          existing.deleted_at = nil
          existing.deleted_by = nil
          existing.created_by = current_consumer.id
          existing.save!

          return render json: FavoriteBlueprint.render_as_hash(existing), status: :created
        end

        favorite.save!

        render json: FavoriteBlueprint.render_as_hash(favorite), status: :created
      end

      # Favorite has no updated_at/updated_by column (see db/structure.sql)
      # — nothing to stamp, but the record is still resolved through
      # current_consumer.favorites so cross-consumer updates 404.
      def update
        @favorite.update!(favorite_params)

        render json: FavoriteBlueprint.render_as_hash(@favorite)
      end

      def destroy
        @favorite.soft_delete!(current_consumer.id)
        head :no_content
      end

      private

      # Scoped to current_consumer.favorites, not Favorite.find — a
      # favorite belonging to another consumer must 404, not leak.
      def set_favorite
        @favorite = current_consumer.favorites.find(params[:id])
      end

      # consumer_id is intentionally not permitted here: ownership always
      # comes from current_consumer, never from client input.
      def favorite_params
        params.require(:favorite).permit(:merchant_id)
      end
    end
  end
end
