"use client";

import Image from "next/image";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { cn } from "@/lib/utils/cn";
import { formatArs, type GiftTier, type GiftTierKey } from "@/lib/gift/tiers";

export type GiftTierPickerProps = {
  tiers: readonly GiftTier[];
  selectedKey: GiftTierKey;
  /** Label shown on the custom-amount tile's face — "Tu monto" until a valid amount is entered. */
  customAmountLabel: string;
  onSelect: (key: GiftTierKey) => void;
};

/**
 * The four gift-card tiles. Phone (< 900px) scrolls them horizontally at a
 * fixed card size; wide (>= 900px) wraps them into a fluid grid — same
 * structural split as `docs/design-reference/Fudo App.dc.html` (horizontal
 * `overflow-x: auto` row) vs. `Fudo Customers.dc.html`
 * (`repeat(auto-fit, minmax(240px, 1fr))`), following the same 900px switch
 * `AppNav` uses instead of a CSS-only breakpoint.
 */
export function GiftTierPicker({
  tiers,
  selectedKey,
  customAmountLabel,
  onSelect,
}: GiftTierPickerProps) {
  const isPhone = useIsPhoneViewport();

  return (
    <div
      className={cn(
        isPhone
          ? "-mx-[clamp(16px,3vw,32px)] flex gap-3.5 overflow-x-auto px-[clamp(16px,3vw,32px)] pb-1"
          : "grid grid-cols-[repeat(auto-fit,minmax(240px,1fr))] gap-[18px]",
      )}
    >
      {tiers.map((tier) => {
        const active = tier.key === selectedKey;
        const amountLabel = tier.amount === null ? customAmountLabel : formatArs(tier.amount);

        return (
          <button
            key={tier.key}
            type="button"
            onClick={() => onSelect(tier.key)}
            aria-pressed={active}
            style={{
              background: tier.gradient,
              borderColor: active ? tier.ringColor : undefined,
              boxShadow: active
                ? `0 16px 40px rgba(0,0,0,0.45), 0 0 0 2px ${tier.ringColor}`
                : "0 10px 26px rgba(0,0,0,0.3)",
            }}
            className={cn(
              "relative flex flex-none flex-col justify-between overflow-hidden rounded-[20px] border border-border text-left transition-transform duration-300 ease-out",
              isPhone ? "h-[152px] w-[244px] p-4" : "h-[186px] w-full p-5",
              active ? "-translate-y-1 scale-100" : "translate-y-0 scale-[0.97]",
            )}
          >
            <span className="flex items-center justify-between">
              <Image
                src="/fudo-logo.png"
                alt=""
                width={200}
                height={50}
                className={cn("h-auto opacity-95", isPhone ? "w-[54px]" : "w-[62px]")}
              />
              <span
                className="text-[9.5px] font-bold tracking-[0.16em]"
                style={{ color: tier.badgeColor }}
              >
                {tier.badge}
              </span>
            </span>

            <span className="flex flex-col gap-1.5 text-left">
              <span
                className={cn(
                  "font-heading font-black leading-none text-white",
                  isPhone ? "text-[30px]" : "text-[34px]",
                )}
              >
                {amountLabel}
              </span>
              <span className="text-[11.5px] leading-snug text-white/72">{tier.perk}</span>
            </span>
          </button>
        );
      })}
    </div>
  );
}
