"use client";

import { cn } from "@/lib/utils/cn";
import { toggleFavoriteMerchant, useIsMerchantFavorite } from "@/lib/favorites/favorites-store";

// The heart/favorite toggle on merchant cards and the detail page header
// (`p.fav`/`favCurrent` in the design references). Backed by the shared
// `lib/favorites/favorites-store.ts` (localStorage, not the real
// `favorites` table — see that module's header comment for exactly why),
// so toggling a merchant here is what makes it show up under Perfil →
// Favoritos, and stays consistent across every card/instance for the same
// merchant instead of each button keeping its own independent, page-reload-
// losing `useState` (the previous implementation).

interface FavoriteButtonProps {
  merchantId: number;
  /** "overlay" (card corner, dark translucent chip) vs "plain" (detail header, on top of the cover photo). */
  variant?: "overlay" | "plain";
  className?: string;
}

export function FavoriteButton({
  merchantId,
  variant = "overlay",
  className,
}: FavoriteButtonProps) {
  const favorite = useIsMerchantFavorite(merchantId);

  return (
    <button
      type="button"
      aria-pressed={favorite}
      aria-label={favorite ? "Quitar de favoritos" : "Guardar en favoritos"}
      onClick={(event) => {
        event.preventDefault();
        event.stopPropagation();
        toggleFavoriteMerchant(merchantId);
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
