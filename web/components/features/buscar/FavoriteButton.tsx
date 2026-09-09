"use client";

import { useState } from "react";
import { cn } from "@/lib/utils/cn";

// The heart/favorite toggle on merchant cards and the detail page header
// (`p.fav`/`favCurrent` in the design references). Ephemeral component
// state only — a real favorite needs the `favorites` table + a logged-in
// consumer (see lib/api/README.md's "Out of scope: auth": favorites live in
// the mobile app, not this web platform), so this resets on reload instead
// of pretending to persist something this app has no backend call for yet.
// Swap the two state hooks below for a real mutation once that lands; every
// caller already passes `merchantId` it would need.

interface FavoriteButtonProps {
  merchantId: number;
  initialFavorite?: boolean;
  /** "overlay" (card corner, dark translucent chip) vs "plain" (detail header, on top of the cover photo). */
  variant?: "overlay" | "plain";
  className?: string;
}

export function FavoriteButton({
  merchantId,
  initialFavorite = false,
  variant = "overlay",
  className,
}: FavoriteButtonProps) {
  const [favorite, setFavorite] = useState(initialFavorite);

  return (
    <button
      type="button"
      aria-pressed={favorite}
      aria-label={favorite ? `Quitar ${merchantId} de favoritos` : `Guardar en favoritos`}
      onClick={(event) => {
        event.preventDefault();
        event.stopPropagation();
        setFavorite((current) => !current);
      }}
      className={cn(
        "flex h-9 w-9 flex-none items-center justify-center rounded-full transition-transform active:scale-90",
        variant === "overlay"
          ? "bg-black/60 backdrop-blur-sm"
          : "border border-border bg-surface shadow-[inset_0_1px_0_var(--highlight)]",
        className,
      )}
    >
      <span
        aria-hidden
        className="material-symbols text-[19px]"
        style={{
          color: favorite ? "#FF5023" : "#FFFFFF",
          fontVariationSettings: favorite
            ? "'FILL' 1, 'wght' 250, 'GRAD' 0, 'opsz' 24"
            : "'FILL' 0, 'wght' 250, 'GRAD' 0, 'opsz' 24",
        }}
      >
        favorite
      </span>
    </button>
  );
}
