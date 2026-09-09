"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { LoyaltyRule, Merchant } from "@/lib/types";
import { useSession } from "@/lib/session/use-session";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { getLoyaltyRulesForMerchant, buildLoyaltyProgress } from "@/lib/data/loyalty";
import { useVisitHistory } from "@/lib/visits/use-visit-history";
import { cn } from "@/lib/utils/cn";
import { LoyaltyHeroCard } from "./LoyaltyHeroCard";
import { LoyaltyRoadmap } from "./LoyaltyRoadmap";

// The loyalty/visit-progress tab (`mLoyal`/`loyaltyOf()` in
// docs/design-reference/Fudo App.dc.html) — real login-gating, not cosmetic:
// a logged-out visitor sees the program explained in the abstract plus a CTA
// to log in ("Recompensas" framing, matches the design's `!authed` copy
// branch); a logged-in consumer sees their real visit ladder instead.
// `useSession()` is backed by a real session — see
// lib/session/session-provider.tsx — so both branches below actually render
// depending on whether the visitor is logged in.
//
// `loyalty_rules` (real, via lib/data/loyalty.ts) is public, so it's fetched
// regardless of auth. The visit count that drives progress is real too
// (`visit_summaries`, via `useVisitHistory()`, filtered to this merchant) —
// that hook already no-ops without a stored token, so this never fires an
// authenticated request for a logged-out visitor.
export function LoyaltyCard({ merchant }: { merchant: Merchant }) {
  const { isAuthenticated } = useSession();
  const isPhone = useIsPhoneViewport();
  const { visitSummaries, loading: visitsLoading } = useVisitHistory();
  const [rules, setRules] = useState<LoyaltyRule[] | null>(null);
  const [rulesError, setRulesError] = useState(false);

  // No synchronous `setRules(null)`/`setRulesError(false)` reset up front —
  // `rules` already starts `null` (the loading state) on first render, and
  // `merchant` doesn't change without remounting this component in
  // practice, so there's nothing to reset. Every `setState` call here goes
  // through a `.then()`/`.catch()` callback, same as
  // lib/consumer-settings/use-notifications-setting.ts, to stay clear of the
  // `react-hooks/set-state-in-effect` lint rule (see use-require-auth.ts's
  // header comment for the same constraint on synchronous effect-body
  // `setState`).
  useEffect(() => {
    let cancelled = false;

    getLoyaltyRulesForMerchant(merchant)
      .then((result) => {
        if (cancelled) return;
        setRules(result);
        setRulesError(false);
      })
      .catch(() => {
        if (!cancelled) setRulesError(true);
      });

    return () => {
      cancelled = true;
    };
  }, [merchant]);

  if (rulesError) {
    return (
      <p className="rounded-card border border-border bg-surface p-4 text-[13px] text-foreground-muted">
        No pudimos cargar los premios de {merchant.name}. Probá de nuevo más tarde.
      </p>
    );
  }

  // Wait for BOTH sources before rendering real content when logged in:
  // `rules` (public loyalty_rules, fast) resolves before `visitSummaries`
  // (authenticated visit_summaries, backed by `useVisitHistory()`'s own
  // `loading`) almost every time — `visitSummaries` starts as `[]`, so
  // gating only on `rules` rendered "0 visitas · Arrancá tu camino" for an
  // authenticated consumer with real visits, then jumped to the real count
  // once `useVisitHistory` finished. A logged-out visitor never fetches
  // visits at all (see useVisitHistory's header comment), so there's
  // nothing to wait on in that case.
  if (rules === null || (isAuthenticated && visitsLoading)) {
    return (
      <div
        aria-busy="true"
        className="h-[140px] animate-pulse rounded-hero border border-border bg-surface"
      />
    );
  }

  const visits = isAuthenticated
    ? (visitSummaries.find((summary) => summary.merchant_id === merchant.id)?.count ?? 0)
    : 0;
  const progress = buildLoyaltyProgress(rules, visits, isAuthenticated);
  const size = isPhone ? "phone" : "wide";

  // Same `loyal.note` card in both references, just 20px/12.5px (phone) vs
  // 21px icon/13px text/15px padding/12px gap (wide) — cheap enough to keep
  // inline instead of a third extracted component for five lines of markup.
  const qrNote = (
    <div
      className={cn(
        "flex items-center rounded-card border border-border bg-surface",
        isPhone ? "gap-2.5 p-3.5" : "gap-3 p-[15px]",
      )}
    >
      <span
        aria-hidden
        className={cn(
          "material-symbols text-foreground-muted",
          isPhone ? "text-[20px]" : "text-[21px]",
        )}
      >
        qr_code_scanner
      </span>
      <p
        className={cn(
          "flex-1 leading-relaxed text-foreground-muted",
          isPhone ? "text-[12.5px]" : "text-[13px]",
        )}
      >
        {progress.note}
      </p>
    </div>
  );

  // Logged-out gate — real, not cosmetic: neither `.dc.html` reference gates
  // this section at all (their mock `loyaltyOf()` renders the same ladder at
  // 0 visits with generic copy for a logged-out visitor), but this app
  // deliberately doesn't expose an unauthenticated visitor's visit-ladder
  // shape at all, replacing it with a CTA instead — same gate, same copy, on
  // both phone and wide (see this file's header comment).
  const loginCta = (
    <div className="flex flex-col gap-3 rounded-card border border-accent/32 bg-surface p-[18px] shadow-[inset_0_1px_0_var(--highlight)]">
      <span className="flex h-10 w-10 items-center justify-center rounded-[13px] bg-accent-soft">
        <span aria-hidden className="material-symbols text-[21px] text-accent">
          lock
        </span>
      </span>
      <div className="font-heading text-lg font-extrabold text-foreground">Recompensas</div>
      <p className="text-[13px] leading-relaxed text-foreground-muted">
        Iniciá sesión para ver tu progreso real de visitas en {merchant.name} y sumar a tus
        premios escaneando el QR del local.
      </p>
      <Link
        href="/perfil"
        className="rounded-full bg-gradient-to-b from-cta-from to-cta-to px-4 py-3 text-center text-[14px] font-semibold text-white shadow-cta"
      >
        Iniciar sesión
      </Link>
    </div>
  );

  // Wide + authenticated is the only case that actually reflows: the
  // reference's `grid-template-columns: repeat(auto-fit, minmax(330px, 1fr))`
  // (Fudo Customers.dc.html line ~586) puts the hero card + QR note in one
  // sub-column and the roadmap in the other, side by side. Every other
  // combination (phone, or wide-but-logged-out) stays the single flowing
  // column both references otherwise use — see this file's header comment
  // for why logged-out never shows the roadmap to split against in the
  // first place.
  if (isAuthenticated && !isPhone) {
    return (
      <div
        className="grid items-start gap-[22px]"
        style={{ gridTemplateColumns: "repeat(auto-fit, minmax(330px, 1fr))" }}
      >
        <div className="flex flex-col gap-4">
          <LoyaltyHeroCard progress={progress} size="wide" />
          {qrNote}
        </div>
        <LoyaltyRoadmap merchantName={merchant.name} steps={progress.steps} size="wide" />
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-4">
      <LoyaltyHeroCard progress={progress} size={size} />
      {isAuthenticated ? (
        <LoyaltyRoadmap merchantName={merchant.name} steps={progress.steps} size={size} />
      ) : (
        loginCta
      )}
      {qrNote}
    </div>
  );
}
