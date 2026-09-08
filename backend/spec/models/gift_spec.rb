require "rails_helper"

# Business rule (see PRD.md: "Regalar — comprar y enviar un regalo a otra
# persona"): a gift can be sent to someone who is not yet a Fudo Consumers
# user — it's addressed by phone number, and the recipient consumer account
# is linked later if/when they sign up and claim it. This spec confirms
# `recipient_consumer_id` is genuinely optional at the model level, while
# `recipient_phone` (the only way to reach an unregistered recipient) stays
# mandatory regardless.
RSpec.describe Gift, type: :model do
  let(:sender) do
    Consumer.create!(
      first_name: "Ana",
      last_name: "Gomez",
      email: "ana.#{SecureRandom.hex(6)}@example.com",
      password_hash: "hashed-password",
      dni: SecureRandom.random_number(10**8).to_s,
      created_by: SecureRandom.uuid
    )
  end

  def build_gift(attrs = {})
    Gift.new(
      {
        sender: sender,
        type: "classic",
        amount: 5000,
        recipient_phone: "+5491122334455",
        expires_at: 30.days.from_now,
        created_by: SecureRandom.uuid
      }.merge(attrs)
    )
  end

  it "allows a gift sent to a phone number with no registered recipient consumer yet" do
    gift = build_gift(recipient: nil)

    expect(gift).to be_valid
    expect { gift.save! }.not_to raise_error
  end

  it "still requires a recipient phone even when there is no recipient consumer" do
    gift = build_gift(recipient: nil, recipient_phone: nil)

    expect(gift).not_to be_valid
    expect(gift.errors[:recipient_phone]).to be_present
  end

  it "defaults new gifts to pending status" do
    gift = build_gift(recipient: nil)
    gift.save!

    expect(gift.reload.status).to eq("pending")
  end
end
