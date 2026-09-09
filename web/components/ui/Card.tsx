import type { HTMLAttributes } from "react";
import { cn } from "@/lib/utils/cn";

export type CardProps = HTMLAttributes<HTMLDivElement> & {
  /** Adds the hover border-accent treatment used by tappable cards (e.g. a
   * merchant result) — omit for a purely static surface. */
  interactive?: boolean;
};

/**
 * The design's one repeated "panel" look: `--surf` background, hairline
 * `--line` border, 20px radius, and a 1px inset top highlight that reads as
 * a subtle glass edge (`box-shadow: inset 0 1px 0 var(--hi)` in the
 * reference — see e.g. the filter panel in Fudo Customers.dc.html).
 */
export function Card({
  interactive = false,
  className,
  ...props
}: CardProps) {
  return (
    <div
      className={cn(
        "rounded-card border border-border bg-surface shadow-[inset_0_1px_0_var(--highlight)]",
        interactive &&
          "transition-colors duration-200 hover:border-accent/50",
        className,
      )}
      {...props}
    />
  );
}
