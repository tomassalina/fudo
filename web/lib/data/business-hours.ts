// Data-layer facade for business hours — see lib/data/merchants.ts for the
// mock/real switching rationale. The real branch has no dedicated
// endpoint to call (see lib/api/README.md's assumption note) — it reads
// `business_hours` off the same merchant-detail fetch `getMerchantById`
// uses, deduped per request via `fetchMerchantDetail`'s `cache()` wrapper
// so this doesn't cost a second network round trip.
//
// The formatting/grouping helpers are pure (no I/O) and re-exported as-is
// from lib/mock/business-hours instead of being duplicated here.

import type { BusinessHours } from "@/lib/types";
import { getBusinessHoursForMerchant as getMockBusinessHoursForMerchant } from "@/lib/mock/business-hours";
import { isApiConfigured } from "@/lib/api/client";
import { fetchMerchantDetail } from "@/lib/api/merchants";

export async function getBusinessHoursForMerchant(
  merchantId: number,
): Promise<BusinessHours[]> {
  if (!isApiConfigured()) {
    return getMockBusinessHoursForMerchant(merchantId);
  }
  const detail = await fetchMerchantDetail(merchantId);
  return detail?.business_hours ?? [];
}

export {
  DAY_LABELS_SHORT,
  buildOpeningHoursSpecification,
  formatDayHours,
  groupBusinessHoursByDay,
} from "@/lib/mock/business-hours";
export type { DayHours } from "@/lib/mock/business-hours";
