module Api
  module V1
    class FavoritesController < BaseController
      before_action :set_favorite, only: %i[show update destroy]

      def index
        favorites = paginate(filtered_favorites)

        render json: {
          data: FavoriteBlueprint.render_as_hash(favorites, view: :list),
          meta: pagination_meta(favorites)
        }
      end

      def show
        render json: FavoriteBlueprint.render_as_hash(@favorite)
      end

      def create
        return unless (actor_id = require_actor_id!)

        favorite = Favorite.new(favorite_params)
        favorite.created_by = actor_id
        favorite.save!

        render json: FavoriteBlueprint.render_as_hash(favorite), status: :created
      end

      # Favorite has no updated_at/updated_by column (see
      # db/structure.sql) — nothing to stamp, so no actor is required here.
      def update
        @favorite.update!(favorite_params)

        render json: FavoriteBlueprint.render_as_hash(@favorite)
      end

      def destroy
        return unless (actor_id = require_actor_id!)

        @favorite.soft_delete!(actor_id)
        head :no_content
      end

      private

      def set_favorite
        @favorite = Favorite.find(params[:id])
      end

      def favorite_params
        params.require(:favorite).permit(:consumer_id, :merchant_id)
      end

      def filtered_favorites
        scope = Favorite.all
        scope = scope.where(consumer_id: params[:consumer_id]) if params[:consumer_id].present?
        scope
      end
    end
  end
end
