import type { LoyaltyStep } from "@/lib/types";
import { cn } from "@/lib/utils/cn";

/**
 * "TU CAMINO EN [MERCHANT]" — the numbered visit-ladder timeline, same
 * `loyal.pathLabel`/`loyal.steps` block in both design references (phone:
 * `Fudo App.dc.html` line ~510, wide: `Fudo Customers.dc.html` line ~610).
 * Only rendered for an authenticated visitor (LoyaltyCard shows the
 * login-gate card instead while logged out — see that file's header
 * comment for why this codebase's gate differs from the references, which
 * don't gate this section at all).
 *
 * `size` only changes the reward/type/badge text sizes (14px/11.5px/10px
 * wide vs 13.5px/11px/9.5px phone) — the label, step gap, dot size and
 * connecting line are identical pixel values in both references, so those
 * stay unparameterized.
 */
export function LoyaltyRoadmap({
  merchantName,
  steps,
  size,
}: {
  merchantName: string;
  steps: LoyaltyStep[];
  size: "phone" | "wide";
}) {
  const wide = size === "wide";

  return (
    <div>
      <p className="pb-3.5 text-[11px] font-bold uppercase tracking-widest text-foreground-faint">
        Tu camino en {merchantName}
      </p>
      <div className="flex flex-col">
        {steps.map((step) => (
          <div key={step.visitNumber} className="flex min-h-[44px] gap-3.5">
            <div className="relative flex w-[26px] flex-none flex-col items-center">
              {step.visitNumber < steps.length ? (
                <span
                  aria-hidden
                  className="absolute top-1 bottom-0 w-0.5"
                  style={{
                    background: step.done ? "rgba(255,80,35,0.55)" : "var(--border)",
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
                    step.done ? "#FF5023" : step.isNext ? "rgba(255,80,35,0.6)" : "var(--border)"
                  }`,
                  color: step.done ? "#FFFFFF" : step.isNext ? "#FF7A55" : "var(--foreground-faint)",
                  boxShadow: step.done
                    ? "0 4px 12px rgba(255,80,35,0.3)"
                    : step.isNext
                      ? "0 0 0 5px rgba(255,80,35,0.08)"
                      : "none",
                }}
              >
                {step.visitNumber}
              </span>
            </div>
            <div className="flex min-w-0 flex-1 items-center justify-between gap-2.5">
              {step.rule ? (
                <div
                  className={cn(
                    "flex min-w-0 flex-wrap items-baseline",
                    wide ? "gap-[9px]" : "gap-2",
                  )}
                >
                  <span
                    className={cn(
                      "font-semibold leading-tight text-foreground",
                      wide ? "text-[14px]" : "text-[13.5px]",
                    )}
                  >
                    {step.rule.reward_description}
                  </span>
                  <span className={cn("text-foreground-faint", wide ? "text-[11.5px]" : "text-[11px]")}>
                    {step.rule.is_permanent ? "beneficio permanente" : "premio único"}
                  </span>
                </div>
              ) : (
                <span className="h-px flex-1 bg-border" />
              )}
              {step.isHere ? (
                <span
                  className={cn(
                    "flex-none rounded-full bg-success-soft font-bold text-success",
                    wide ? "px-2 py-[3px] text-[10px]" : "px-1.5 py-0.5 text-[9.5px]",
                  )}
                >
                  ESTÁS ACÁ
                </span>
              ) : null}
              {step.isNext ? (
                <span
                  className={cn(
                    "flex-none rounded-full bg-accent-soft font-bold text-accent-light",
                    wide ? "px-2 py-[3px] text-[10px]" : "px-1.5 py-0.5 text-[9.5px]",
                  )}
                >
                  PRÓXIMO
                </span>
              ) : null}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}
