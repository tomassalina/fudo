module Api
  module V1
    # ACCEPTED LIMITATION: see the comment atop MerchantsController — any
    # authenticated consumer can write menu items for any merchant, no
    # staff/ownership model exists yet.
    class MenuItemsController < BaseController
      before_action :authenticate_consumer!, except: %i[index show]
      before_action :set_menu_item, only: %i[show update destroy]

      def index
        menu_items = paginate(filtered_menu_items)

        render json: {
          data: MenuItemBlueprint.render_as_hash(menu_items, view: :list),
          meta: pagination_meta(menu_items)
        }
      end

      def show
        render json: MenuItemBlueprint.render_as_hash(@menu_item, view: :extended)
      end

      def create
        menu_item = MenuItem.new(menu_item_params)
        menu_item.created_by = current_consumer.id
        menu_item.save!

        render json: MenuItemBlueprint.render_as_hash(menu_item, view: :extended), status: :created
      end

      def update
        @menu_item.assign_attributes(menu_item_params)
        @menu_item.updated_by = current_consumer.id
        @menu_item.save!

        render json: MenuItemBlueprint.render_as_hash(@menu_item, view: :extended)
      end

      def destroy
        @menu_item.soft_delete!(current_consumer.id)
        head :no_content
      end

      private

      def set_menu_item
        @menu_item = MenuItem.find(params[:id])
      end

      def menu_item_params
        params.require(:menu_item).permit(
          :merchant_id, :name, :description, :price, :currency, :section,
          :image_url, :active
        )
      end

      def filtered_menu_items
        scope = MenuItem.all
        scope = scope.where(merchant_id: params[:merchant_id]) if params[:merchant_id].present?
        scope
      end
    end
  end
end
