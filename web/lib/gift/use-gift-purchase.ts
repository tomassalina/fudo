"use client";

import { useMemo, useState } from "react";
import { ApiError } from "@/lib/api/client";
import { createGift, type GiftErrorBody, type GiftType } from "@/lib/api/gifts";
import { forceLogout } from "@/lib/session/session-provider";
import {
  CUSTOM_AMOUNT_MAX,
  CUSTOM_AMOUNT_MIN,
  formatArs,
  GIFT_TIERS,
  type GiftTierKey,
} from "./tiers";

export type CustomAmountHintTone = "neutral" | "error" | "success";

export interface CustomAmountHint {
  tone: CustomAmountHintTone;
  message: string;
}

/** Tier tile -> backend `gift_type_enum` value. "custom" is the Platinum
 * tile (see tiers.ts's `GIFT_TIERS`), the only tier without a fixed amount. */
const GIFT_TYPE_BY_TIER: Record<GiftTierKey, GiftType> = {
  clasica: "classic",
  gold: "gold",
  black: "black",
  custom: "platinum",
};

/** Every gift's `expires_at` is exactly 12 months from purchase — matches
 * GiftCheckoutForm's static "vence en 12 meses" copy. The backend requires
 * `expires_at` (`Gift` validates its presence, no DB default — confirmed
 * live: `POST /gifts` with none 422s `{"expires_at":["can't be blank"]}`),
 * so this is what actually supplies it, not a display-only label. */
function twelveMonthsFromNow(): string {
  const date = new Date();
  const originalDay = date.getDate();
  date.setFullYear(date.getFullYear() + 1);
  // `setFullYear` overflows into the next month when the original day
  // doesn't exist in the target year (Feb 29 -> Mar 1 in a non-leap year).
  // Clamp back to the last valid day of the intended month instead.
  if (date.getDate() !== originalDay) {
    date.setDate(0);
  }
  return date.toISOString();
}

/** Backend-provided message for a failed purchase, or a sensible Spanish
 * fallback — same convention as `loginErrorMessage`/`registerErrorMessage`
 * in lib/session/session-provider.tsx. 401 is handled by the caller
 * (`forceLogout()`), not here — see `buy()` below. */
function purchaseErrorMessage(error: unknown): string {
  if (error instanceof ApiError) {
    if (error.status === 422) {
      const body = error.body as GiftErrorBody | undefined;
      const errors = body?.errors ?? {};
      if (errors.recipient_phone) {
        return "Ingresá un teléfono de destinatario válido.";
      }
      if (errors.amount) {
        return "Ese monto no es válido.";
      }
      // Covers expires_at/type — neither is user-editable, so a generic
      // message is more honest than guessing which one failed.
      return "No pudimos completar la compra. Intentá de nuevo.";
    }
    if (error.status === undefined) {
      return "No pudimos conectarnos con Fudo. Probá de nuevo en unos segundos.";
    }
  }
  return "Ocurrió un error al comprar la gift card. Intentá de nuevo.";
}

/**
 * Owns all the "Regalar" purchase-flow state and validation, mirroring the
 * reference's derived-state block 1:1 (see `Fudo App.dc.html`, the
 * `const raw = ...` / `customErr` / `payAmount` / `canBuy` lines right before
 * the render's return). Kept separate from the presentational components so
 * `GiftTierPicker` / `CustomAmountInput` / `GiftCheckoutForm` stay dumb.
 */
export function useGiftPurchase() {
  const [tierKey, setTierKey] = useState<GiftTierKey>("clasica");
  // Stored pre-formatted (e.g. "121.000"), same as the reference's
  // `customAmount` state — re-derived from the raw digits on every change.
  const [customAmount, setCustomAmount] = useState("");
  const [recipientPhone, setRecipientPhone] = useState("");
  const [message, setMessage] = useState("");
  const [purchased, setPurchased] = useState(false);
  const [purchasing, setPurchasing] = useState(false);
  const [purchaseError, setPurchaseError] = useState<string | null>(null);
  // The real `POST /gifts` response for the last successful purchase — the
  // confirmation UI reads `.id` from this instead of a canned message, see
  // RegalarPage.
  const [purchasedGiftId, setPurchasedGiftId] = useState<number | null>(null);

  const selectedTier = useMemo(
    () => GIFT_TIERS.find((tier) => tier.key === tierKey) ?? GIFT_TIERS[0],
    [tierKey],
  );
  const isCustomTier = tierKey === "custom";

  const rawDigits = customAmount.replace(/[.,]/g, "");
  const parsedAmount = rawDigits === "" ? null : Number(rawDigits);

  let customError = "";
  if (rawDigits !== "") {
    if (!/^\d+$/.test(rawDigits)) {
      customError = "Usá solo números";
    } else if (parsedAmount !== null && parsedAmount < CUSTOM_AMOUNT_MIN) {
      customError = `El mínimo es ${formatArs(CUSTOM_AMOUNT_MIN)}`;
    } else if (parsedAmount !== null && parsedAmount > CUSTOM_AMOUNT_MAX) {
      customError = `El máximo es ${formatArs(CUSTOM_AMOUNT_MAX)}`;
    }
  }
  const validCustomAmount = !customError && parsedAmount ? parsedAmount : 0;

  const payAmount = isCustomTier ? validCustomAmount : (selectedTier.amount ?? 0);
  const canPay = payAmount > 0 && !purchasing;

  const customHint: CustomAmountHint = customError
    ? { tone: "error", message: customError }
    : validCustomAmount
      ? { tone: "success", message: `Gift card de ${formatArs(validCustomAmount)}` }
      : {
          tone: "neutral",
          message: `Entre ${formatArs(CUSTOM_AMOUNT_MIN)} y ${formatArs(CUSTOM_AMOUNT_MAX)}`,
        };

  const buyLabel = purchasing
    ? "Enviando…"
    : isCustomTier && !validCustomAmount
      ? customError
        ? "Corregí el monto"
        : "Ingresá un monto"
      : `Comprar y enviar ${formatArs(payAmount)}`;

  function selectTier(key: GiftTierKey) {
    setTierKey(key);
  }

  // Reference: `const d = e.target.value.replace(/\D/g, "").slice(0, 7);`
  function onCustomAmountChange(rawInput: string) {
    const digits = rawInput.replace(/\D/g, "").slice(0, 7);
    setCustomAmount(digits ? Number(digits).toLocaleString("es-AR") : "");
  }

  /** Real purchase against `POST /api/v1/gifts` (lib/api/gifts.ts). On a
   * 401 (expired/invalid token), this calls `forceLogout()` — same
   * established pattern as favorites-store.ts's `handleFavoriteError`: it
   * flips `isAuthenticated` to `false`, and RegalarPage swaps this whole
   * form out for `LoginRequiredCard` on its own, so there's nothing else to
   * do here for that case. Every other failure sets `purchaseError` for
   * GiftCheckoutForm to render. */
  async function buy() {
    if (!canPay) return;

    setPurchaseError(null);
    setPurchasing(true);
    try {
      const gift = await createGift({
        type: GIFT_TYPE_BY_TIER[tierKey],
        amount: payAmount,
        recipient_phone: recipientPhone,
        message: message.trim() === "" ? undefined : message,
        expires_at: twelveMonthsFromNow(),
      });
      setPurchasedGiftId(gift.id);
      setPurchased(true);
    } catch (error) {
      if (error instanceof ApiError && error.status === 401) {
        forceLogout();
      } else {
        setPurchaseError(purchaseErrorMessage(error));
      }
    } finally {
      setPurchasing(false);
    }
  }

  function resetPurchase() {
    setPurchased(false);
    setPurchaseError(null);
    setPurchasedGiftId(null);
    setRecipientPhone("");
    setMessage("");
  }

  return {
    tiers: GIFT_TIERS,
    tierKey,
    selectedTier,
    isCustomTier,
    selectTier,
    customAmount,
    onCustomAmountChange,
    customHint,
    payAmount,
    payAmountLabel: formatArs(payAmount),
    canPay,
    buyLabel,
    recipientPhone,
    setRecipientPhone,
    message,
    setMessage,
    buy,
    purchasing,
    purchaseError,
    purchased,
    purchasedGiftId,
    resetPurchase,
  };
}

export type GiftPurchase = ReturnType<typeof useGiftPurchase>;
