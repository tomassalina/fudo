import { describe, expect, it } from "vitest";
import {
  getAvailableRewards,
  getVisitHistory,
  tierForVisits,
} from "@/lib/mock/visit-history";
import { getMockVisitCount } from "@/lib/mock/loyalty";

describe("tierForVisits", () => {
  it("mirrors the design reference's tierOf() thresholds", () => {
    expect(tierForVisits(0)).toBe("Bronce");
    expect(tierForVisits(3)).toBe("Bronce");
    expect(tierForVisits(4)).toBe("Plata");
    expect(tierForVisits(7)).toBe("Plata");
    expect(tierForVisits(8)).toBe("Oro");
    expect(tierForVisits(20)).toBe("Oro");
  });
});

describe("getVisitHistory", () => {
  it("only includes merchants with at least one mocked visit", () => {
    const history = getVisitHistory();
    expect(history.length).toBeGreaterThan(0);
    for (const entry of history) {
      expect(getMockVisitCount(entry.merchant)).toBeGreaterThan(0);
      expect(entry.progress.visits).toBe(getMockVisitCount(entry.merchant));
    }
  });

  it("is deterministic across calls", () => {
    const a = getVisitHistory().map((entry) => entry.merchant.id);
    const b = getVisitHistory().map((entry) => entry.merchant.id);
    expect(a).toEqual(b);
  });

  it("assigns the tier consistent with the merchant's mock visit count", () => {
    for (const entry of getVisitHistory()) {
      expect(entry.tier).toBe(tierForVisits(entry.progress.visits));
    }
  });
});

describe("getAvailableRewards", () => {
  it("only reports rewards for merchants that appear in the visit history", () => {
    const historyIds = new Set(getVisitHistory().map((entry) => entry.merchant.id));
    for (const reward of getAvailableRewards()) {
      expect(historyIds.has(reward.merchant.id)).toBe(true);
    }
  });

  it("gives every upcoming reward a positive visitsRemaining", () => {
    for (const reward of getAvailableRewards()) {
      if (reward.status === "upcoming") {
        expect(reward.visitsRemaining).toBeGreaterThan(0);
      } else {
        expect(reward.visitsRemaining).toBeUndefined();
      }
    }
  });
});
