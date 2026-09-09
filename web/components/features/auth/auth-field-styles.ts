import { cn } from "@/lib/utils/cn";

/**
 * Shared text-input treatment for every auth field (Login/Register) — 14px
 * radius, hairline border, 14px padding, per the design reference's login
 * and edit-profile inputs (both dc.html files use the exact same input
 * style for every text field). The one thing that *does* differ by
 * viewport: background. Phone renders straight on the page background
 * (`--bg`), so inputs use the lighter `--surf` to stand out; wide wraps the
 * form in a `--surf` panel (see AuthShell), so inputs go back down to `--bg`
 * for contrast against that panel instead.
 */
export function authInputClassName(isPhone: boolean) {
  return cn(
    "w-full rounded-[14px] border border-border p-3.5 text-[14px] text-foreground outline-none transition-colors placeholder:text-foreground-faint focus:border-accent/60",
    isPhone ? "bg-surface" : "bg-background",
  );
}
