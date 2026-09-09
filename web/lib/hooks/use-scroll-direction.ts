"use client";

// Generic scroll-direction visibility hook — shared by any floating chrome
// that should get out of the way while the visitor is reading (scrolling
// down) and come back the moment they want to navigate again (scrolling up,
// or returning to the top of the page). First consumer is the phone bottom
// nav (`PhoneNav.tsx`); the floating "Mapa" button on `/buscar` is meant to
// reuse this same hook rather than growing its own copy — keep this file
// free of anything nav-specific (no routes, no icons, no nav markup) so it
// stays a drop-in for both.

import { useEffect, useRef, useState } from "react";

export type UseScrollDirectionOptions = {
  /**
   * How many pixels the page must scroll in one direction before that
   * direction "counts" — filters out the sub-pixel/rubber-band jitter that
   * fires on every `scroll` event (trackpads, iOS momentum scroll, mouse
   * wheel micro-steps) so the element doesn't flicker visible/hidden on
   * tiny movements. Default `8`.
   */
  threshold?: number;
  /**
   * While the scroll position is within this many pixels of the top of the
   * page, the hook always reports `visible: true` regardless of direction —
   * there's no content above to have scrolled past, so hiding the element
   * here would just be confusing. Default `0` (only the exact top).
   */
  topOffset?: number;
};

export type UseScrollDirectionResult = {
  /**
   * `true` when the consumer should be shown: the page is scrolling up, is
   * within `topOffset` of the top, or hasn't scrolled enough yet to cross
   * `threshold`. `false` while actively scrolling down past `topOffset`.
   */
  visible: boolean;
  /** Raw last-detected direction, for callers that want more than the
   * binary `visible` flag (e.g. to animate differently per direction).
   * `null` before the first qualifying scroll event. */
  direction: "up" | "down" | null;
};

const DEFAULT_THRESHOLD = 8;
const DEFAULT_TOP_OFFSET = 0;

/**
 * Tracks vertical scroll direction and derives a `visible` flag meant to
 * drive show/hide chrome (a floating nav, a floating action button) that
 * should retreat on scroll-down and return on scroll-up — the common
 * "auto-hiding toolbar" pattern.
 *
 * Renders `visible: true` on the server/first paint (see
 * `lib/hooks/use-viewport.ts` for the same "safe" SSR-guess reasoning): the
 * element should be shown until we actually know the visitor is scrolling
 * down, and a server render has no scroll position to read anyway.
 */
export function useScrollDirection(
  options: UseScrollDirectionOptions = {},
): UseScrollDirectionResult {
  const { threshold = DEFAULT_THRESHOLD, topOffset = DEFAULT_TOP_OFFSET } = options;

  const [state, setState] = useState<UseScrollDirectionResult>({
    visible: true,
    direction: null,
  });

  // Mutable, doesn't need to trigger re-renders on its own — only `state`
  // updates (via setState) should cause a re-render.
  const lastY = useRef(0);

  useEffect(() => {
    lastY.current = window.scrollY;

    let ticking = false;

    function evaluate() {
      ticking = false;
      const currentY = window.scrollY;
      const delta = currentY - lastY.current;

      if (currentY <= topOffset) {
        lastY.current = currentY;
        setState((prev) => (prev.visible ? prev : { visible: true, direction: prev.direction }));
        return;
      }

      if (Math.abs(delta) < threshold) return;

      const direction = delta > 0 ? "down" : "up";
      lastY.current = currentY;
      setState((prev) =>
        prev.direction === direction && prev.visible === (direction === "up")
          ? prev
          : { visible: direction === "up", direction },
      );
    }

    function onScroll() {
      if (ticking) return;
      ticking = true;
      requestAnimationFrame(evaluate);
    }

    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, [threshold, topOffset]);

  return state;
}
