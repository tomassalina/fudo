"use client";

import type { ReactNode } from "react";
import { useIsPhoneViewport } from "@/lib/hooks/use-viewport";
import { cn } from "@/lib/utils/cn";

export type SheetProps = {
  open: boolean;
  onClose: () => void;
  title?: string;
  children: ReactNode;
  /**
   * Extra content rendered between the title row and the scrollable body —
   * e.g. the filter sheet's "N filtros activos" pill. Optional: every
   * existing call site (QR sheet, edit-profile sheet, sort menu, hero
   * search) renders exactly as before when this is omitted.
   */
  headerExtra?: ReactNode;
  /**
   * Non-scrolling content pinned below the scrollable body — e.g. the
   * filter sheet's Limpiar/Aplicar footer. Optional, same
   * backward-compatible rationale as `headerExtra`.
   */
  footer?: ReactNode;
  /**
   * Stacks this sheet above another already-open Sheet (a filter row
   * opening its own options sub-sheet) instead of sharing the same layer —
   * see `docs/design-reference/Fudo App.dc.html`'s nested `filtersOpen` /
   * `optOpen` sheets (z-index 9 vs 11 there).
   */
  elevated?: boolean;
  /** Additive classes on the dialog panel — e.g. a fixed/max height. */
  className?: string;
  /** Override for the title's default size/weight (25px/900 for a primary
   * entry sheet like Filtros; a nested detail sheet like the option picker
   * uses a smaller 19px/800 per the design reference). */
  titleClassName?: string;
  /**
   * Overrides the scrollable body wrapper's default `px-6 pb-8 pt-4`
   * entirely — pass a self-contained class string (including any
   * flex/overflow you need) when the default padding doesn't fit, e.g. a
   * full-bleed rows list or a nested option-picker's own padding.
   */
  bodyClassName?: string;
  /**
   * Wide-viewport (vw>=900) presentation. Defaults to "sheet" — every
   * existing call site keeps rendering as a bottom sheet on wide screens
   * too, unchanged. "modal" opts a call site into a small, centered dialog
   * on wide screens instead (see the home hero's type-of-place picker),
   * while the phone layout (vw<900) always stays the bottom sheet — this
   * only ever changes the wide presentation.
   */
  wideVariant?: "sheet" | "modal";
};

/**
 * Bottom sheet: a dimmed veil (`fudoVeil`) behind a panel that slides up
 * from the bottom edge (`fudoSheet`) — the same pair of animations the
 * design reuses for every modal surface (QR sheet, filters, gift/profile
 * dialogs). This is the generic shell; feature sheets provide their own
 * `children`, and — since /buscar's filters sheet needs a header pill row,
 * a pinned footer, and a nested options sub-sheet above it — the optional
 * `headerExtra`/`footer`/`elevated` props above.
 *
 * On wide viewports (vw>=900), a call site can opt into `wideVariant="modal"`
 * to render as a small centered dialog (with its own internal scroll) rather
 * than a bottom sheet stretched to `max-w-lg` — the bottom-sheet pattern
 * reads as a mobile affordance once there's no screen edge to anchor to.
 * Phone stays the bottom sheet regardless of `wideVariant`.
 */
export function Sheet({
  open,
  onClose,
  title,
  children,
  headerExtra,
  footer,
  elevated = false,
  className,
  titleClassName,
  bodyClassName,
  wideVariant = "sheet",
}: SheetProps) {
  const isPhone = useIsPhoneViewport();
  const isCenteredModal = wideVariant === "modal" && !isPhone;

  if (!open) return null;

  return (
    <div
      role="presentation"
      onClick={onClose}
      className={cn(
        "fixed inset-0 flex bg-black/60 backdrop-blur-sm animate-fudo-veil",
        isCenteredModal ? "items-center justify-center p-4" : "items-end justify-center",
        elevated ? "z-50" : "z-40",
      )}
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(event) => event.stopPropagation()}
        className={cn(
          "flex w-full flex-col border-border bg-background shadow-floating",
          isCenteredModal
            ? "max-w-[420px] max-h-[85vh] animate-fudo-in rounded-sheet border"
            : "max-w-lg animate-fudo-sheet rounded-t-sheet border-t",
          className,
        )}
      >
        {isCenteredModal ? null : (
          <div className="mx-auto mt-2.5 h-1 w-11 flex-none rounded-full bg-foreground-faint/60" />
        )}
        <div
          className={cn(
            "flex flex-none items-center justify-between px-5",
            isCenteredModal ? "pt-5" : "pt-3.5",
          )}
        >
          {title ? (
            <h2
              className={cn(
                "font-heading font-black text-foreground",
                titleClassName ?? "text-[25px]",
              )}
            >
              {title}
            </h2>
          ) : (
            <span />
          )}
          <button
            type="button"
            onClick={onClose}
            aria-label="Cerrar"
            className="flex h-[34px] w-[34px] flex-none items-center justify-center rounded-full bg-surface text-foreground-faint transition-colors hover:text-foreground"
          >
            <span aria-hidden className="material-symbols text-[19px]">
              close
            </span>
          </button>
        </div>
        {headerExtra ? <div className="flex-none px-5 pt-3.5">{headerExtra}</div> : null}
        <div className={cn("min-h-0", bodyClassName ?? "flex-1 overflow-y-auto px-6 pb-8 pt-4")}>
          {children}
        </div>
        {footer ? (
          <div className="flex-none border-t border-border px-5 pt-4 pb-6.5">{footer}</div>
        ) : null}
      </div>
    </div>
  );
}
