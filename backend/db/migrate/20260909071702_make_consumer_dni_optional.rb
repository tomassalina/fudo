class MakeConsumerDniOptional < ActiveRecord::Migration[8.1]
  # DNI is loaded by the waiter at checkout in the physical restaurant, not
  # by the consumer at self-registration (see openspec/changes/
  # fudo-consumers-mvp/design.md, Decision 1). `dni_encrypted`/`dni_bidx`
  # were NOT NULL, which made registration without a DNI impossible at the
  # DB level regardless of the model-level validation. `idx_consumers_dni_bidx`
  # stays a plain (non-partial) unique index: Postgres treats every NULL as
  # distinct for uniqueness purposes, so multiple consumers with no DNI yet
  # don't collide with each other, and the index still enforces uniqueness
  # once a DNI is set.
  def change
    change_column_null :consumers, :dni_encrypted, true
    change_column_null :consumers, :dni_bidx, true
  end
end
