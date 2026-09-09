class AddIndexesToGifts < ActiveRecord::Migration[8.1]
  def change
    # Single-column indexes, not composite: GiftsController#accessible_gifts
    # queries `where(sender_consumer_id: ...).or(where(recipient_consumer_id: ...))`,
    # and a composite index can't serve an OR across two independent
    # equality lookups the way two single-column indexes can.
    add_index :gifts, :sender_consumer_id, name: "idx_gifts_sender_consumer_id"
    add_index :gifts, :recipient_consumer_id, name: "idx_gifts_recipient_consumer_id"
  end
end
