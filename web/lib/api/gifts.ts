// Real fetch implementation for the authenticated `gifts` resource
// (`backend/app/controllers/api/v1/gifts_controller.rb`). Every gift is
// created by the current consumer as sender — see GiftsController#create,
// there is no anonymous/mock mode (same as favorites/consumer_settings).
//
// Confirmed shapes by curling the live backend with a real token:
//   POST /api/v1/gifts
//   {"gift":{"type":"classic","amount":12000,"recipient_phone":"+5491122334455","message":"Feliz cumple!","expires_at":"2027-09-09T07:51:55Z"}}
//   -> 201 {"id":129,"amount":"12000.0","created_at":"2026-09-09T07:51:55.373Z",
//           "expires_at":"2027-09-09T07:51:55.000Z","message":"Feliz cumple!",
//           "recipient_consumer_id":null,"recipient_phone":"+5491122334455",
//           "sender_consumer_id":"...","status":"pending","status_updated_at":null,
//           "type":"classic","updated_at":"2026-09-09T07:51:55.373Z"}
//   -> 422 {"errors":{"recipient_phone":["can't be blank"]}}
//   -> 422 {"errors":{"amount":["must be greater than or equal to 0"]}}
//   -> 422 {"errors":{"expires_at":["can't be blank"]}}
//   -> 401 {"error":"Not authenticated"} (no/invalid token)
//
// GET /api/v1/gifts (the `:list` blueprint view — no recipient_phone/message/
// timestamps, see gift_blueprint.rb and spec/requests/api/v1/gifts_spec.rb)
// confirmed live too, but nothing under web/ reads it yet — see the "gifts
// received/sent" profile-view note in this change's final report.

import { apiFetch } from "./client";
import { authHeader } from "@/lib/auth/token-storage";

export type GiftType = "classic" | "gold" | "black" | "platinum";
export type GiftStatus = "pending" | "redeemed" | "expired" | "cancelled";

/** Wire shape of `GiftBlueprint`'s `:extended` view — what `POST /gifts`,
 * `GET /gifts/:id` and `PATCH /gifts/:id` all return. `amount` comes back as
 * a decimal-serialized-as-string ("12000.0"), same as every other `decimal`
 * column on this API — confirmed live, not a typo, callers that need a
 * number should `Number(raw.amount)`. */
export interface RawGift {
  id: number;
  sender_consumer_id: string;
  recipient_consumer_id: string | null;
  type: GiftType;
  amount: string;
  status: GiftStatus;
  expires_at: string;
  recipient_phone: string;
  message: string | null;
  status_updated_at: string | null;
  created_at: string;
  updated_at: string;
}

/** `recipient_consumer_id` and `status` are intentionally not accepted here
 * — see `gift_create_params`/`#create` in gifts_controller.rb: the sender is
 * always `current_consumer` and every new gift starts `pending`, neither is
 * ever client-chosen. */
export interface GiftCreateInput {
  type: GiftType;
  amount: number;
  recipient_phone: string;
  /** Omit (don't send an empty string) when the buyer left it blank — the
   * column is nullable and this keeps the payload consistent with
   * RegisterInput's optional-field convention (lib/api/auth.ts). */
  message?: string;
  expires_at: string;
}

/** Backend validation-error shape, confirmed live above — same
 * `{ errors: { field: ["message", ...] } }` shape `RegistrationErrorBody`
 * (lib/api/auth.ts) and favorites' 422s already use. */
export interface GiftErrorBody {
  errors?: Record<string, string[]>;
}

export async function createGift(input: GiftCreateInput): Promise<RawGift> {
  return apiFetch<RawGift>("/gifts", {
    method: "POST",
    headers: { ...authHeader(), "Content-Type": "application/json" },
    body: JSON.stringify({ gift: input }),
  });
}
