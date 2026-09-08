# Soft-delete support for models with a `deleted_at`/`deleted_by` column
# pair. Included models are scoped to non-deleted rows by default; call
# `soft_delete!` instead of `destroy` to remove a record from view without
# losing the row.
module SoftDeletable
  extend ActiveSupport::Concern

  included do
    default_scope { where(deleted_at: nil) }

    # `dependent: :restrict_with_error` (declared on the model's has_many
    # associations) only guards a real `destroy`, but soft delete goes
    # through `update!`/`save!` instead. This replicates the same guard for
    # the `:soft_delete` validation context so a record with active
    # (non-soft-deleted) restricted children still fails instead of being
    # silently soft-deleted out from under them.
    validate :no_active_restricted_dependents, on: :soft_delete
  end

  # Marks the record as deleted without removing the row. Any has_many
  # association declared with `dependent: :destroy` has no soft-delete
  # column of its own (see the models' comments — they're pure join/derived
  # rows), so a real `destroy` would hard-delete them; soft-deleting via
  # `save!` alone would skip that entirely and leave them orphaned. Destroy
  # those dependents here too, in the same transaction as the save, so the
  # net effect matches what a real `destroy` would have done to them.
  def soft_delete!(actor_id)
    self.deleted_at = Time.current
    self.deleted_by = actor_id

    self.class.transaction do
      save!(context: :soft_delete)
      destroy_cascade_dependents!
    end
  end

  private

  def destroy_cascade_dependents!
    self.class.reflect_on_all_associations(:has_many).each do |reflection|
      next unless reflection.options[:dependent] == :destroy

      public_send(reflection.name).destroy_all
    end
  end

  def no_active_restricted_dependents
    self.class.reflect_on_all_associations(:has_many).each do |reflection|
      next unless reflection.options[:dependent] == :restrict_with_error
      next unless public_send(reflection.name).exists?

      errors.add(:base, "Cannot delete record because dependent #{reflection.name.to_s.humanize.downcase} exist")
    end
  end
end
