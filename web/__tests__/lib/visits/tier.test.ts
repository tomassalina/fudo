import { describe, expect, it } from "vitest";
import { tierForVisits } from "@/lib/visits/tier";

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
