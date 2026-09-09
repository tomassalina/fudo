import { Card } from "@/components/ui/Card";

/**
 * Desktop grid-card loading placeholder — mirrors the real `MerchantCard`
 * "card" layout 1:1 so results don't jump size once they arrive: the same
 * `aspect-[16/10]` image area (not a hardcoded height, see commit 3703399)
 * inside the same `rounded-card`/`border-border`/`bg-surface` card shell,
 * with a shimmer sweep over the image and text-line placeholders sized off
 * the design's own skeleton spec (`skeletons` in
 * `docs/design-reference/Fudo Customers.dc.html`'s isList grid — `height:
 * 16px/60%`, `12px/45%`, `12px/30%` bars under a shimmering 16:10 box).
 *
 * Shared by `SearchResultsGrid.tsx` (lazy-load "loading more" fill) and
 * `BuscarSkeleton.tsx` (route-level initial loading state) so both moments
 * render the identical shape instead of two hand-copied blocks. Phone's
 * loading-more placeholder (`RowSkeleton` in `SearchResultsGrid.tsx`) has
 * its own row shape and doesn't use this.
 *
 * Uses the shared `Card` primitive (same shell `MerchantCard` renders via
 * `<Card as="article">`) instead of hand-copying its classes, so the shell
 * styling can't silently drift between the real card and its skeleton.
 */
export function CardSkeleton() {
  return (
    <Card aria-hidden className="flex flex-col overflow-hidden">
      <div className="relative aspect-[16/10] w-full overflow-hidden bg-surface-2">
        <span className="absolute inset-0 animate-fudo-shimmer bg-gradient-to-r from-transparent via-[var(--highlight)] to-transparent" />
      </div>
      <div className="flex flex-col gap-2.5 p-4">
        <span className="h-4 w-[60%] rounded-md bg-surface-2" />
        <span className="h-3 w-[45%] rounded-md bg-surface-2" />
        <span className="h-3 w-[30%] rounded-md bg-surface-2" />
      </div>
    </Card>
  );
}
