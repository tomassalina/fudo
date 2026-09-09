import { describe, expect, it } from "vitest";
import { QR_GRID_SIZE, formatConsumerQrId, generateQrCells } from "@/lib/mock/qr-grid";

describe("generateQrCells", () => {
  it("returns one cell per grid position", () => {
    expect(generateQrCells()).toHaveLength(QR_GRID_SIZE * QR_GRID_SIZE);
  });

  it("is deterministic across calls", () => {
    expect(generateQrCells()).toEqual(generateQrCells());
  });

  it("draws a finder pattern ring (not filled) one cell in from each corner box's border", () => {
    const cells = generateQrCells();
    const at = (row: number, col: number) => cells[row * QR_GRID_SIZE + col];

    // Top-left finder box origin (0,0): the border ring is filled...
    expect(at(0, 0)).toBe(true);
    // ...but the cell just inside the ring, before the inner 3x3 block, is not.
    expect(at(1, 1)).toBe(false);
    // ...and the inner 3x3 block (rows/cols 2-4) is filled again.
    expect(at(3, 3)).toBe(true);
  });
});

describe("formatConsumerQrId", () => {
  it("formats as FD-XXXX-XXXX using the id's digits", () => {
    expect(formatConsumerQrId("1234567890")).toBe("FD-1234-5678");
  });

  it("pads with zeros when the id has fewer than 8 digits", () => {
    expect(formatConsumerQrId("ab-cd-12")).toBe("FD-1200-0000");
  });
});
