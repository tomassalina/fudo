module Api
  module V1
    class TagsController < BaseController
      before_action :set_tag, only: %i[show update destroy]

      def index
        tags = paginate(Tag.all)

        render json: {
          data: TagBlueprint.render_as_hash(tags, view: :list),
          meta: pagination_meta(tags)
        }
      end

      def show
        render json: TagBlueprint.render_as_hash(@tag, view: :extended)
      end

      def create
        return unless (actor_id = require_actor_id!)

        tag = Tag.new(tag_params)
        tag.created_by = actor_id
        tag.save!

        render json: TagBlueprint.render_as_hash(tag, view: :extended), status: :created
      end

      def update
        return unless (actor_id = require_actor_id!)

        @tag.assign_attributes(tag_params)
        @tag.updated_by = actor_id
        @tag.save!

        render json: TagBlueprint.render_as_hash(@tag, view: :extended)
      end

      def destroy
        return unless (actor_id = require_actor_id!)

        @tag.soft_delete!(actor_id)
        head :no_content
      end

      private

      def set_tag
        @tag = Tag.find(params[:id])
      end

      def tag_params
        params.require(:tag).permit(:name)
      end
    end
  end
end
