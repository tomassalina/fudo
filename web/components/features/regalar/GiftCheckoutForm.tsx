"use client";

import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { cn } from "@/lib/utils/cn";

export type GiftCheckoutFormProps = {
  recipientPhone: string;
  onRecipientPhoneChange: (value: string) => void;
  message: string;
  onMessageChange: (value: string) => void;
  payAmountLabel: string;
  buyLabel: string;
  canPay: boolean;
  onBuy: () => void;
  /** Backend-provided (or network-fallback) message from the last failed
   * `POST /api/v1/gifts` — sourced from lib/gift/use-gift-purchase.ts's
   * `purchaseError`, `null` when there's nothing to show. */
  error?: string | null;
};

const fieldClass =
  "rounded-[14px] border border-border bg-surface p-3.5 text-sm text-foreground shadow-[inset_0_1px_0_var(--highlight)] outline-none placeholder:text-foreground-faint";

const inlineFieldClass =
  "min-w-0 flex-1 border-0 bg-transparent text-[17px] text-foreground outline-none placeholder:text-foreground-faint";

/**
 * The logged-in checkout step: recipient phone + optional message, then the
 * buy button. `buyBg`/`buyInk`/`buyCursor` in the reference switch on
 * `canBuy` rather than a shared button style, so this deliberately doesn't
 * reach for `components/ui/Button` — a disabled buy button is a flat
 * `--surf2` fill, not a dimmed CTA gradient.
 */
export function GiftCheckoutForm({
  recipientPhone,
  onRecipientPhoneChange,
  message,
  onMessageChange,
  payAmountLabel,
  buyLabel,
  canPay,
  onBuy,
  error,
}: GiftCheckoutFormProps) {
  const isPhone = useIsPhoneViewport();

  const errorMessage = error ? (
    <p role="alert" className="text-[13px] text-accent-light">
      {error}
    </p>
  ) : null;

  const buyButton = (
    <button
      type="button"
      onClick={onBuy}
      disabled={!canPay}
      className={cn(
        "relative overflow-hidden rounded-full font-sans font-semibold transition-transform duration-200 active:scale-[0.98]",
        canPay
          ? "cursor-pointer bg-gradient-to-b from-cta-from to-cta-to text-white shadow-cta"
          : "cursor-not-allowed bg-surface-2 text-foreground-faint shadow-[inset_0_1px_0_var(--highlight)]",
        isPhone ? "mt-1.5 w-full py-4 text-[15px]" : "px-[34px] py-[17px] text-[15.5px]",
      )}
    >
      {canPay ? (
        <span
          aria-hidden="true"
          className="pointer-events-none absolute inset-y-[-40%] left-0 w-1/3 animate-fudo-sheen [animation-duration:3.6s] bg-gradient-to-r from-transparent via-white/40 to-transparent"
        />
      ) : null}
      <span className="relative">{buyLabel}</span>
    </button>
  );

  if (isPhone) {
    return (
      <div className="flex flex-col gap-2.5 pt-[22px]">
        <div className="pb-1 text-[11px] font-bold tracking-[0.1em] text-foreground-faint">
          PARA QUIÉN
        </div>
        <input
          value={recipientPhone}
          onChange={(event) => onRecipientPhoneChange(event.target.value)}
          placeholder="Teléfono del destinatario"
          className={fieldClass}
        />
        <input
          value={message}
          onChange={(event) => onMessageChange(event.target.value)}
          placeholder="Mensaje (opcional)"
          className={fieldClass}
        />
        {errorMessage}
        {buyButton}
      </div>
    );
  }

  return (
    <div className="mt-[26px] flex flex-wrap items-end justify-between gap-7 rounded-[24px] border border-border bg-surface px-7 py-[26px] shadow-[inset_0_1px_0_var(--highlight)]">
      <div className="min-w-[280px] flex-1">
        <div className="text-[11px] font-bold tracking-[0.1em] text-foreground-faint">
          PARA QUIÉN
        </div>
        <div className="flex items-center gap-3.5 border-b border-border pt-3.5 pb-3.5">
          <span className="material-symbols text-xl text-foreground-faint">call</span>
          <input
            value={recipientPhone}
            onChange={(event) => onRecipientPhoneChange(event.target.value)}
            placeholder="Teléfono del destinatario"
            className={inlineFieldClass}
          />
        </div>
        <div className="flex items-center gap-3.5 pt-4">
          <span className="material-symbols text-xl text-foreground-faint">chat_bubble</span>
          <input
            value={message}
            onChange={(event) => onMessageChange(event.target.value)}
            placeholder="Escribile un mensaje (opcional)"
            className={inlineFieldClass}
          />
        </div>
      </div>

      <div className="flex flex-none flex-col items-end gap-3">
        <div className="flex items-baseline gap-2.5">
          <span className="text-[13px] text-foreground-faint">Total</span>
          <span className="font-heading text-[34px] font-black text-foreground">
            {payAmountLabel}
          </span>
        </div>
        {errorMessage}
        {buyButton}
        <div className="text-[11.5px] text-foreground-faint">
          Se envía por WhatsApp · vence en 12 meses
        </div>
      </div>
    </div>
  );
}
