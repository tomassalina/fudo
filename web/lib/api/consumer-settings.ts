// Real fetch implementations for the authenticated `consumer_settings`
// resource (`backend/app/controllers/api/v1/consumer_settings_controller.rb`).
// `ConsumerSetting` is a `has_one` off `Consumer` (uniqueness-enforced, see
// backend/app/models/consumer_setting.rb) — there is no "get mine" shortcut
// route, only the standard `index`/`show`/`create`/`update`/`destroy`
// resource, so callers fetch the index (scoped server-side to
// `current_consumer`, at most one row) and either see one row or none: a
// brand-new consumer has no `ConsumerSetting` row at all until something
// creates one (confirmed: `registrations_controller.rb` does not create one
// on signup).
//
// Confirmed shape by curling the live backend with the demo consumer's
// token:
//   GET /api/v1/consumer_settings
//   -> 200 {"data":[{"id":9,"consumer_id":"...","notifications_enabled":true,"theme":"dark","updated_at":"..."}],"meta":{...}}

import { apiFetch } from "./client";
import { authHeader } from "@/lib/auth/token-storage";

export interface RawConsumerSetting {
  id: number;
  consumer_id: string;
  theme: "light" | "dark" | "system";
  notifications_enabled: boolean;
  updated_at: string;
}

interface ConsumerSettingsListResponse {
  data: RawConsumerSetting[];
  meta: { current_page: number; total_pages: number; total_count: number; per_page: number };
}

export interface ConsumerSettingInput {
  theme?: RawConsumerSetting["theme"];
  notifications_enabled?: boolean;
}

/** `null` when this consumer has no `ConsumerSetting` row yet — not an
 * error, just "never created one" (see the header comment). */
export async function fetchConsumerSetting(): Promise<RawConsumerSetting | null> {
  const response = await apiFetch<ConsumerSettingsListResponse>(
    "/consumer_settings?per_page=1",
    { headers: authHeader() },
  );
  return response.data[0] ?? null;
}

export async function createConsumerSetting(
  input: ConsumerSettingInput,
): Promise<RawConsumerSetting> {
  return apiFetch<RawConsumerSetting>("/consumer_settings", {
    method: "POST",
    headers: { ...authHeader(), "Content-Type": "application/json" },
    body: JSON.stringify({ consumer_setting: input }),
  });
}

export async function updateConsumerSetting(
  id: number,
  input: ConsumerSettingInput,
): Promise<RawConsumerSetting> {
  return apiFetch<RawConsumerSetting>(`/consumer_settings/${id}`, {
    method: "PATCH",
    headers: { ...authHeader(), "Content-Type": "application/json" },
    body: JSON.stringify({ consumer_setting: input }),
  });
}
