import type { LoyaltyProgress } from "@/lib/types";
import { cn } from "@/lib/utils/cn";

/**
 * The dark gradient "visits ring + headline" card at the top of the loyalty
 * tab — `loyal.heroBg`/`loyal.ringBg` block in both design references
 * (`docs/design-reference/Fudo App.dc.html` line ~493 for phone,
 * `Fudo Customers.dc.html` line ~588 for wide). Renders identically whether
 * the visitor is authenticated or not — `buildLoyaltyProgress`
 * (lib/data/loyalty.ts) already produces sensible generic copy for the
 * logged-out case (`headline: "Así funcionan los premios"` etc.), same as
 * both references do (they never gate this specific card on auth either).
 *
 * `size` picks between the two references' distinct dimensions (78px vs
 * 92px ring, 20px vs 24px padding, etc.) — everything else about the card
 * (gradient background, ring treatment, DOM order) is identical between
 * them, so this stays one component instead of two near-duplicates. The
 * ring itself is a flat two-tone circle (not a true conic-gradient tied to
 * visit %), same simplification the previous phone implementation already
 * made: neither reference's `ringBg` value is real data — it's a fixed
 * per-tier decorative gradient from a mock `TIERS_L` table this codebase's
 * real `buildLoyaltyProgress` has no equivalent for (see learnings.md).
 */
export function LoyaltyHeroCard({
  progress,
  size,
}: {
  progress: LoyaltyProgress;
  size: "phone" | "wide";
}) {
  const wide = size === "wide";

  return (
    <div
      className={cn(
        "relative overflow-hidden rounded-hero border border-accent/25 bg-gradient-to-br from-[#241a14] to-[#171821] shadow-hero",
        wide ? "p-6" : "p-5",
      )}
    >
      <div className={cn("relative flex items-center", wide ? "gap-[18px]" : "gap-4")}>
        <div
          className={cn(
            "flex flex-none items-center justify-center rounded-full bg-black/30",
            wide ? "h-[92px] w-[92px]" : "h-[78px] w-[78px]",
          )}
        >
          <div
            className={cn(
              "flex flex-col items-center justify-center rounded-full bg-black/55",
              wide ? "h-[74px] w-[74px]" : "h-[62px] w-[62px]",
            )}
          >
            <span
              className={cn(
                "font-heading font-black leading-none text-white",
                wide ? "text-[30px]" : "text-2xl",
              )}
            >
              {progress.visits}
            </span>
            <span className={cn("tracking-[0.1em] text-white/60", wide ? "text-[9.5px]" : "text-[9px]")}>
              VISITAS
            </span>
          </div>
        </div>
        <div className="min-w-0 flex-1">
          <div
            className={cn(
              "font-bold text-accent-light",
              wide ? "text-[10.5px] tracking-[0.16em]" : "text-[10px] tracking-[0.16em]",
            )}
          >
            {progress.tierLabel}
          </div>
          <div
            className={cn(
              "font-heading font-black leading-[1.12] text-white",
              wide ? "pt-1.5 text-[25px]" : "pt-1 text-xl",
            )}
          >
            {progress.headline}
          </div>
          <p
            className={cn(
              "leading-[1.4] text-white/70",
              wide ? "pt-[7px] text-[13.5px]" : "pt-1.5 text-[12.5px]",
            )}
          >
            {progress.sub}
          </p>
        </div>
      </div>
    </div>
  );
}
