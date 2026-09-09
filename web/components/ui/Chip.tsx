import type { ButtonHTMLAttributes } from "react";
import { cn } from "@/lib/utils/cn";

export type ChipProps = ButtonHTMLAttributes<HTMLButtonElement> & {
  active?: boolean;
};

/**
 * Pill-shaped filter/tag control — active vs. inactive treatment matches
 * every toggle chip in the design (filters, result-mode switches, AI query
 * tags): a soft accent fill when on, a hairline surface outline when off.
 */
export function Chip({ active = false, className, ...props }: ChipProps) {
  return (
    <button
      type="button"
      className={cn(
        "inline-flex flex-none items-center gap-1.5 whitespace-nowrap rounded-full border px-3.5 py-1.5 text-[13px] font-semibold transition-colors duration-200",
        active
          ? "border-accent/35 bg-accent-soft text-accent-light"
          : "border-border bg-surface text-foreground-faint hover:border-accent/50 hover:text-foreground",
        className,
      )}
      {...props}
    />
  );
}
