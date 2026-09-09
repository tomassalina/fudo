module Api
  module V1
    # ACCEPTED LIMITATION: see the comment atop MerchantsController — any
    # authenticated consumer can write tags regardless of merchant
    # ownership, no staff/ownership model exists yet.
    class TagsController < BaseController
      before_action :authenticate_consumer!, except: %i[index show]
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
        tag = Tag.new(tag_params)
        tag.created_by = current_consumer.id
        tag.save!

        render json: TagBlueprint.render_as_hash(tag, view: :extended), status: :created
      end

      def update
        @tag.assign_attributes(tag_params)
        @tag.updated_by = current_consumer.id
        @tag.save!

        render json: TagBlueprint.render_as_hash(@tag, view: :extended)
      end

      def destroy
        @tag.soft_delete!(current_consumer.id)
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
