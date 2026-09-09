"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { LoyaltyRule, Merchant } from "@/lib/types";
import { useSession } from "@/lib/session/use-session";
import { getLoyaltyRulesForMerchant, buildLoyaltyProgress } from "@/lib/data/loyalty";
import { useVisitHistory } from "@/lib/visits/use-visit-history";

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

  return (
    <div className="flex flex-col gap-4">
      <div className="relative overflow-hidden rounded-hero border border-accent/25 bg-gradient-to-br from-[#241a14] to-[#171821] p-5 shadow-hero">
        <div className="relative flex items-center gap-4">
          <div className="flex h-[78px] w-[78px] flex-none items-center justify-center rounded-full bg-black/30">
            <div className="flex h-[62px] w-[62px] flex-col items-center justify-center rounded-full bg-black/55">
              <span className="font-heading text-2xl font-black leading-none text-white">
                {progress.visits}
              </span>
              <span className="text-[9px] tracking-[0.1em] text-white/60">
                VISITAS
              </span>
            </div>
          </div>
          <div className="min-w-0 flex-1">
            <div className="text-[10px] font-bold tracking-[0.16em] text-accent-light">
              {progress.tierLabel}
            </div>
            <div className="pt-1 font-heading text-xl font-black leading-snug text-white">
              {progress.headline}
            </div>
            <p className="pt-1.5 text-[12.5px] leading-relaxed text-white/70">
              {progress.sub}
            </p>
          </div>
        </div>
      </div>

      {isAuthenticated ? (
        <div>
          <p className="pb-3.5 text-[11px] font-bold uppercase tracking-widest text-foreground-faint">
            Tu camino en {merchant.name}
          </p>
          <div className="flex flex-col">
            {progress.steps.map((step) => (
              <div key={step.visitNumber} className="flex min-h-[44px] gap-3.5">
                <div className="relative flex w-[26px] flex-none flex-col items-center">
                  {step.visitNumber < progress.steps.length ? (
                    <span
                      aria-hidden
                      className="absolute top-1 bottom-0 w-0.5"
                      style={{
                        background: step.done
                          ? "rgba(255,80,35,0.55)"
                          : "var(--border)",
                      }}
                    />
                  ) : null}
                  <span
                    className="relative z-[1] mt-2 flex h-6 w-6 flex-none items-center justify-center rounded-full font-heading text-[11px] font-extrabold"
                    style={{
                      background: step.done
                        ? "#FF5023"
                        : step.isNext
                          ? "rgba(255,80,35,0.14)"
                          : "var(--surface)",
                      border: `1.5px solid ${
                        step.done
                          ? "#FF5023"
                          : step.isNext
                            ? "rgba(255,80,35,0.6)"
                            : "var(--border)"
                      }`,
                      color: step.done
                        ? "#FFFFFF"
                        : step.isNext
                          ? "#FF7A55"
                          : "var(--foreground-faint)",
                    }}
                  >
                    {step.visitNumber}
                  </span>
                </div>
                <div className="flex min-w-0 flex-1 items-center justify-between gap-2.5">
                  {step.rule ? (
                    <div className="flex min-w-0 flex-wrap items-baseline gap-2">
                      <span className="text-[13.5px] font-semibold leading-tight text-foreground">
                        {step.rule.reward_description}
                      </span>
                      <span className="text-[11px] text-foreground-faint">
                        {step.rule.is_permanent ? "beneficio permanente" : "premio único"}
                      </span>
                    </div>
                  ) : (
                    <span className="h-px flex-1 bg-border" />
                  )}
                  {step.isHere ? (
                    <span className="flex-none rounded-full bg-success-soft px-1.5 py-0.5 text-[9.5px] font-bold text-success">
                      ESTÁS ACÁ
                    </span>
                  ) : null}
                  {step.isNext ? (
                    <span className="flex-none rounded-full bg-accent-soft px-1.5 py-0.5 text-[9.5px] font-bold text-accent-light">
                      PRÓXIMO
                    </span>
                  ) : null}
                </div>
              </div>
            ))}
          </div>
        </div>
      ) : (
        <div className="flex flex-col gap-3 rounded-card border border-accent/32 bg-surface p-[18px] shadow-[inset_0_1px_0_var(--highlight)]">
          <span className="flex h-10 w-10 items-center justify-center rounded-[13px] bg-accent-soft">
            <span aria-hidden className="material-symbols text-[21px] text-accent">
              lock
            </span>
          </span>
          <div className="font-heading text-lg font-extrabold text-foreground">
            Recompensas
          </div>
          <p className="text-[13px] leading-relaxed text-foreground-muted">
            Iniciá sesión para ver tu progreso real de visitas en{" "}
            {merchant.name} y sumar a tus premios escaneando el QR del local.
          </p>
          <Link
            href="/perfil"
            className="rounded-full bg-gradient-to-b from-cta-from to-cta-to px-4 py-3 text-center text-[14px] font-semibold text-white shadow-cta"
          >
            Iniciar sesión
          </Link>
        </div>
      )}

      <div className="flex items-center gap-2.5 rounded-card border border-border bg-surface p-3.5">
        <span aria-hidden className="material-symbols text-[20px] text-foreground-muted">
          qr_code_scanner
        </span>
        <p className="flex-1 text-[12.5px] leading-relaxed text-foreground-muted">
          {progress.note}
        </p>
      </div>
    </div>
  );
}
