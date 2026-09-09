// Visual-only QR code grid for the "Mi QR" tab — ports the exact cell
// generator from `docs/design-reference/Fudo App.dc.html` (`const QR = (()
// => {...})()`) so the placeholder is pixel-faithful to the reference: a
// 21×21 grid with three real QR "finder pattern" corners (a filled 3×3 inside
// a 7×7 ring) and a deterministic pseudo-random fill everywhere else. This is
// NOT a real QR code — nothing decodes it — see the doc comment on
// QrMyCodeTab for why that's fine at this phase.
const GRID_SIZE = 21;

function isFinderCell(row: number, col: number): boolean | null {
  const inBox = (r0: number, c0: number) =>
    row >= r0 && row < r0 + 7 && col >= c0 && col < c0 + 7;
  const ring = (r0: number, c0: number) =>
    row === r0 ||
    row === r0 + 6 ||
    col === c0 ||
    col === c0 + 6 ||
    (row >= r0 + 2 && row <= r0 + 4 && col >= c0 + 2 && col <= c0 + 4);

  for (const [r0, c0] of [
    [0, 0],
    [0, 14],
    [14, 0],
  ] as const) {
    if (inBox(r0, c0)) return ring(r0, c0);
  }
  return null;
}

/**
 * Returns `GRID_SIZE * GRID_SIZE` booleans (row-major) — `true` = filled
 * cell. Deterministic (same fixed seed the reference uses), so the same
 * consumer sees a stable-looking code across renders instead of one that
 * flickers with every re-render.
 */
export function generateQrCells(): boolean[] {
  const cells: boolean[] = [];
  let seed = 7;

  for (let row = 0; row < GRID_SIZE; row++) {
    for (let col = 0; col < GRID_SIZE; col++) {
      const finder = isFinderCell(row, col);
      if (finder !== null) {
        cells.push(finder);
        continue;
      }
      // Same linear congruential generator as the reference, so the
      // "random" fill matches it cell-for-cell.
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      cells.push(((seed >> 16) & 3) > 1);
    }
  }

  return cells;
}

export const QR_GRID_SIZE = GRID_SIZE;

/** "FD-4821-7730"-style display id derived from the consumer's real id, so
 * it's stable per-consumer instead of random per render — mirrors `qrId` in
 * the design reference. */
export function formatConsumerQrId(consumerId: string): string {
  const digits = consumerId.replace(/[^0-9]/g, "").padEnd(8, "0");
  return `FD-${digits.slice(0, 4)}-${digits.slice(4, 8)}`;
}
