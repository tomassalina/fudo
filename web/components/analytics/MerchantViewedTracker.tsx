"use client";

import { useEffect } from "react";
import { capture, isPostHogEnabled } from "@/lib/analytics/posthog";

interface MerchantViewedTrackerProps {
  merchantId: number;
  merchantType: string;
}

/** Fires `merchant_viewed` when a /restaurantes/[id] page mounts. */
export function MerchantViewedTracker({
  merchantId,
  merchantType,
}: MerchantViewedTrackerProps) {
  useEffect(() => {
    if (!isPostHogEnabled) return;
    capture("merchant_viewed", {
      merchant_id: merchantId,
      merchant_type: merchantType,
    });
  }, [merchantId, merchantType]);

  return null;
}
