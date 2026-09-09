"use client";

import { useMemo, useState } from "react";
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
  const canPay = payAmount > 0;

  const customHint: CustomAmountHint = customError
    ? { tone: "error", message: customError }
    : validCustomAmount
      ? { tone: "success", message: `Gift card de ${formatArs(validCustomAmount)}` }
      : {
          tone: "neutral",
          message: `Entre ${formatArs(CUSTOM_AMOUNT_MIN)} y ${formatArs(CUSTOM_AMOUNT_MAX)}`,
        };

  const buyLabel =
    isCustomTier && !validCustomAmount
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

  function buy() {
    if (canPay) setPurchased(true);
  }

  function resetPurchase() {
    setPurchased(false);
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
    purchased,
    resetPurchase,
  };
}

export type GiftPurchase = ReturnType<typeof useGiftPurchase>;
