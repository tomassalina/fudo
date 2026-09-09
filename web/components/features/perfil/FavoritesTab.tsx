"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { getMerchantById } from "@/lib/data/merchants";
import { MERCHANT_TYPE_LABELS } from "@/lib/mock/merchants";
import { toggleFavoriteMerchant, useFavoriteMerchantIds } from "@/lib/favorites/favorites-store";
import type { Merchant } from "@/lib/types";

/**
 * "TUS FAVORITOS" — Perfil's `pFavs` tab (`docs/design-reference/Fudo
 * App.dc.html`, `favList`/`noFavs`). Reads favorited merchant ids from the
 * shared `lib/favorites/favorites-store.ts` (localStorage-backed — see that
 * module's header comment for why this isn't the real `favorites` table
 * yet) and resolves each id to a full `Merchant` via the existing
 * `getMerchantById` data facade, so a merchant's name/photo/type here is
 * real data (mock or the live backend, whichever `isApiConfigured()` picks)
 * even though the *favorited* flag itself is local-only.
 */
export function FavoritesTab() {
  const favoriteIds = useFavoriteMerchantIds();
  const [merchants, setMerchants] = useState<Merchant[]>([]);

  useEffect(() => {
    if (favoriteIds.length === 0) return;
    let cancelled = false;

    Promise.all(favoriteIds.map((id) => getMerchantById(id))).then((results) => {
      if (cancelled) return;
      setMerchants(results.filter((merchant): merchant is Merchant => merchant !== null));
    });

    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps -- re-fetch whenever the *set* of ids changes, not on every array identity change from unrelated re-renders.
  }, [favoriteIds.join(",")]);

  // Unfavoriting drops the id from `favoriteIds` immediately (synchronous
  // store update) but `merchants` only catches up once the effect above
  // re-resolves it — filter the stale entry out in the meantime instead of
  // briefly re-showing an unfavorited row.
  const visibleMerchants = merchants.filter((merchant) => favoriteIds.includes(merchant.id));

  if (favoriteIds.length === 0) {
    return (
      <div className="flex flex-col items-center gap-2.5 rounded-card border border-border bg-surface px-5 py-11 text-center">
        <span aria-hidden className="material-symbols text-[30px] text-foreground-faint">
          favorite_border
        </span>
        <p className="max-w-[230px] text-[14px] leading-relaxed text-foreground-muted">
          Marcá lugares con el corazón y aparecen acá.
        </p>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-2.5">
      {visibleMerchants.map((merchant) => (
        <div
          key={merchant.id}
          className="flex items-center gap-3 rounded-[18px] border border-border bg-surface p-2.5 shadow-[inset_0_1px_0_var(--highlight)]"
        >
          <Link
            href={`/restaurantes/${merchant.id}`}
            className="flex min-w-0 flex-1 items-center gap-3"
          >
            <div className="h-14 w-14 flex-none overflow-hidden rounded-[13px] bg-surface-2">
              {merchant.cover_image_url ? (
                // eslint-disable-next-line @next/next/no-img-element -- external mock photos, matches VisitHistoryList.tsx
                <img
                  src={merchant.cover_image_url}
                  alt={merchant.name}
                  loading="lazy"
                  className="h-full w-full object-cover"
                />
              ) : null}
            </div>
            <div className="min-w-0 flex-1">
              <p className="truncate font-heading text-[17px] font-bold text-foreground">
                {merchant.name}
              </p>
              <p className="truncate text-[12px] text-foreground-faint">
                {MERCHANT_TYPE_LABELS[merchant.type]}
                {merchant.neighborhood ? ` · ${merchant.neighborhood}` : ""}
              </p>
            </div>
          </Link>
          <button
            type="button"
            aria-label={`Quitar ${merchant.name} de favoritos`}
            onClick={() => toggleFavoriteMerchant(merchant.id)}
            className="flex-none rounded-full p-1.5 text-accent transition-colors hover:bg-accent-soft"
          >
            <span
              aria-hidden
              className="material-symbols text-[20px]"
              style={{ fontVariationSettings: "'FILL' 1, 'wght' 250, 'GRAD' 0, 'opsz' 24" }}
            >
              favorite
            </span>
          </button>
        </div>
      ))}
    </div>
  );
}
