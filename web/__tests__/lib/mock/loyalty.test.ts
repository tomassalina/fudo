import { describe, expect, it } from "vitest";
import { getLoyaltyProgress, getMockVisitCount } from "@/lib/mock/loyalty";
import { MOCK_MERCHANTS } from "@/lib/mock/merchants";

const merchant = MOCK_MERCHANTS[0];

describe("getLoyaltyProgress (login gating)", () => {
  it("reports zero visits and the logged-out copy when not authenticated, regardless of the mock visit count", () => {
    const progress = getLoyaltyProgress(merchant, false);

    expect(progress.authenticated).toBe(false);
    expect(progress.visits).toBe(0);
    expect(progress.headline).toBe("Así funcionan los premios");
    expect(progress.tierLabel).toBe("PROGRAMA DE FIDELIZACIÓN");
    expect(progress.steps.every((step) => !step.done)).toBe(true);
  });

  it("reports the real mock visit count and progress copy once authenticated", () => {
    const progress = getLoyaltyProgress(merchant, true);
    const expectedVisits = getMockVisitCount(merchant);

    expect(progress.authenticated).toBe(true);
    expect(progress.visits).toBe(expectedVisits);
    expect(progress.tierLabel).toBe("TU CAMINO");
    expect(progress.headline).not.toBe("Así funcionan los premios");
  });

  it("marks exactly the steps up to the visit count as done", () => {
    const progress = getLoyaltyProgress(merchant, true);
    for (const step of progress.steps) {
      expect(step.done).toBe(step.visitNumber <= progress.visits);
    }
  });

  it("always includes a permanent reward at the 10th step", () => {
    const progress = getLoyaltyProgress(merchant, true);
    const last = progress.steps[progress.steps.length - 1];
    expect(last.visitNumber).toBe(10);
    expect(last.rule?.is_permanent).toBe(true);
  });

  it("is deterministic across calls (not randomized) for the same merchant", () => {
    expect(getMockVisitCount(merchant)).toBe(getMockVisitCount(merchant));
  });
});
