"use client";

import Image from "next/image";
import type { CSSProperties } from "react";
import type { GiftTier } from "@/lib/gift/tiers";

export type GiftPurchaseSuccessProps = {
  tier: GiftTier;
  amountLabel: string;
  recipientPhone: string;
  giftId: number | null;
  onDone: () => void;
};

/** Fixed 5-color cycle from the reference's `cols` array — not tier-derived. */
const CONFETTI_COLORS = ["#FF5023", "#FFB08C", "#E0B95C", "#8FD46A", "#FFFFFF"];

/**
 * 18 confetti pieces, deterministic (no `Math.random`) — same formula as the
 * reference's `confetti` derived-state array (`Fudo App.dc.html`, search
 * `confetti: Array.from({ length: 18 }`): evenly spaced launch angles, a
 * distance that grows every 4th piece, and a size/duration/delay that cycle
 * off `i`. Computed once at module scope since it never depends on props.
 */
const CONFETTI = Array.from({ length: 18 }, (_, i) => {
  const angle = (i / 18) * Math.PI * 2;
  const distance = 130 + (i % 4) * 34;
  return {
    key: i,
    width: 6 + (i % 3) * 3,
    height: 6 + (i % 2) * 4,
    color: CONFETTI_COLORS[i % 5],
    dx: Math.cos(angle) * distance,
    dy: Math.sin(angle) * distance - 40,
    rot: (i % 2 ? 1 : -1) * 320,
    duration: 0.9 + (i % 3) * 0.25,
    delay: 0.1 + (i % 5) * 0.04,
  };
});

/**
 * The post-purchase celebration screen — a 1:1 port of the `buying` overlay
 * in the design reference (`docs/design-reference/Fudo App.dc.html`, search
 * `sc-if value="{{ buying }}"`): a dimmed veil, two expanding pulse rings,
 * 18-piece confetti burst, the bought gift card bouncing in with a looping
 * sheen, and the "¡Gift card enviada!" stamp text, all built on the
 * `animate-fudo-*` keyframes already shipped in `app/globals.css`
 * (`fudoVeil`/`fudoRing`/`fudoConfetti`/`fudoCardWin`/`fudoSheen`/`fudoStamp`
 * — every one of these was already defined there before this component
 * existed, just unused). Rendered full-viewport instead of reference's
 * in-phone-frame overlay: this is a real web page, not a mocked phone.
 */
export function GiftPurchaseSuccess({
  tier,
  amountLabel,
  recipientPhone,
  giftId,
  onDone,
}: GiftPurchaseSuccessProps) {
  return (
    <div className="fixed inset-0 z-50 flex flex-col items-center justify-center overflow-hidden bg-[rgba(6,7,12,0.86)] backdrop-blur-md animate-fudo-veil">
      <span
        className="absolute h-[260px] w-[260px] rounded-full border-2 border-accent/50 animate-fudo-ring"
        style={{ animationDelay: "0.15s" }}
      />
      <span
        className="absolute h-[260px] w-[260px] rounded-full border-2 border-accent/35 animate-fudo-ring"
        style={{ animationDelay: "0.35s" }}
      />

      {CONFETTI.map((c) => (
        <span
          key={c.key}
          className="absolute rounded-[2px] animate-fudo-confetti"
          style={
            {
              width: c.width,
              height: c.height,
              backgroundColor: c.color,
              "--dx": `${c.dx}px`,
              "--dy": `${c.dy}px`,
              "--rot": `${c.rot}deg`,
              animationDuration: `${c.duration}s`,
              animationDelay: `${c.delay}s`,
            } as CSSProperties
          }
        />
      ))}

      <div
        className="relative flex h-[172px] w-[274px] flex-col justify-between overflow-hidden rounded-[22px] p-[18px] animate-fudo-card-win"
        style={{
          background: tier.gradient,
          boxShadow: `0 26px 60px rgba(0,0,0,0.6), 0 0 0 2px ${tier.ringColor}`,
        }}
      >
        <span
          className="absolute inset-y-[-40%] w-[90px] animate-fudo-sheen bg-gradient-to-r from-transparent via-white/40 to-transparent"
          style={{ animationDelay: "0.5s" }}
        />
        <span className="relative flex items-center justify-between">
          <Image
            src="/fudo-logo.png"
            alt=""
            width={200}
            height={50}
            className="h-auto w-[62px] opacity-95"
          />
          <span
            className="text-[10px] font-bold tracking-[0.16em]"
            style={{ color: tier.badgeColor }}
          >
            {tier.badge}
          </span>
        </span>
        <span className="relative font-heading text-[38px] font-black text-white">
          {amountLabel}
        </span>
      </div>

      <div
        className="relative pt-[26px] text-center animate-fudo-stamp"
        style={{ animationDelay: "0.35s" }}
      >
        <div className="font-heading text-[26px] font-black text-white">
          ¡Gift card enviada!
        </div>
        <div className="pt-1.5 text-[13.5px] text-white/70">
          {recipientPhone ? `Enviada a ${recipientPhone}` : "Lista para compartir por WhatsApp"}
        </div>
        {giftId ? (
          <div className="pt-1 text-[11.5px] text-white/50">Comprobante Nº {giftId}</div>
        ) : null}
      </div>

      <button
        type="button"
        onClick={onDone}
        className="relative mt-[26px] cursor-pointer rounded-full border border-white/20 bg-white/[0.08] px-[26px] py-[13px] font-sans text-sm font-semibold text-white"
      >
        Listo
      </button>
    </div>
  );
}
