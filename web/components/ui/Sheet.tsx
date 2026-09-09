"use client";

import type { ReactNode } from "react";
import { cn } from "@/lib/utils/cn";

export type SheetProps = {
  open: boolean;
  onClose: () => void;
  title?: string;
  children: ReactNode;
  className?: string;
};

/**
 * Bottom sheet: a dimmed veil (`fudoVeil`) behind a panel that slides up
 * from the bottom edge (`fudoSheet`) — the same pair of animations the
 * design reuses for every modal surface (QR sheet, filters, gift/profile
 * dialogs). This is the generic shell; feature sheets provide their own
 * `children`.
 */
export function Sheet({ open, onClose, title, children, className }: SheetProps) {
  if (!open) return null;

  return (
    <div
      role="presentation"
      onClick={onClose}
      className="fixed inset-0 z-40 flex items-end justify-center bg-black/60 backdrop-blur-sm animate-fudo-veil"
    >
      <div
        role="dialog"
        aria-modal="true"
        aria-label={title}
        onClick={(event) => event.stopPropagation()}
        className={cn(
          "w-full max-w-lg rounded-t-sheet border-t border-border bg-background shadow-floating animate-fudo-sheet",
          className,
        )}
      >
        <div className="mx-auto mt-2.5 h-1 w-10 rounded-full bg-foreground-faint/60" />
        <div className="flex items-center justify-between px-6 pt-4">
          {title ? (
            <h2 className="font-heading text-xl font-black text-foreground">
              {title}
            </h2>
          ) : (
            <span />
          )}
          <button
            type="button"
            onClick={onClose}
            aria-label="Cerrar"
            className="material-symbols -mr-1 rounded-full p-1.5 text-foreground-faint transition-colors hover:text-foreground"
          >
            close
          </button>
        </div>
        <div className="px-6 pb-8 pt-4">{children}</div>
      </div>
    </div>
  );
}
