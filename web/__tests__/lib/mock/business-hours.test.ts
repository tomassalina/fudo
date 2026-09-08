import { describe, expect, it } from "vitest";
import {
  groupBusinessHoursByDay,
  buildOpeningHoursSpecification,
  type DayHours,
} from "@/lib/mock/business-hours";
import type { BusinessHours } from "@/lib/types";

function makeRow(overrides: Partial<BusinessHours> & { id: number }): BusinessHours {
  return {
    merchant_id: 1,
    day_of_week: "monday",
    opens_at: "12:00:00",
    closes_at: "20:00:00",
    closed: false,
    ...overrides,
  };
}

describe("groupBusinessHoursByDay", () => {
  it("marks a day with no rows at all as closed, with no shifts", () => {
    const result = groupBusinessHoursByDay([]);
    expect(result).toHaveLength(7);
    for (const day of result) {
      expect(day.closed).toBe(true);
      expect(day.shifts).toEqual([]);
    }
  });

  it("orders days Monday first regardless of input order", () => {
    const rows = [
      makeRow({ id: 1, day_of_week: "sunday" }),
      makeRow({ id: 2, day_of_week: "monday" }),
    ];
    const result = groupBusinessHoursByDay(rows);
    expect(result.map((d) => d.day)).toEqual([
      "monday",
      "tuesday",
      "wednesday",
      "thursday",
      "friday",
      "saturday",
      "sunday",
    ]);
  });

  it("marks a day open with a valid shift as not closed, with the shift included", () => {
    const rows = [
      makeRow({ id: 1, day_of_week: "monday", opens_at: "12:00:00", closes_at: "20:00:00", closed: false }),
    ];
    const result = groupBusinessHoursByDay(rows);
    const monday = result.find((d) => d.day === "monday")!;
    expect(monday.closed).toBe(false);
    expect(monday.shifts).toEqual([{ opensAt: "12:00:00", closesAt: "20:00:00" }]);
  });

  it("trusts the row's own `closed` flag, not the shift count, when the row is explicitly closed", () => {
    const rows = [
      makeRow({ id: 1, day_of_week: "monday", opens_at: null, closes_at: null, closed: true }),
    ];
    const result = groupBusinessHoursByDay(rows);
    const monday = result.find((d) => d.day === "monday")!;
    expect(monday.closed).toBe(true);
    expect(monday.shifts).toEqual([]);
  });

  it("does NOT mark a day closed when closed:false but opens_at/closes_at are null (open, bad data)", () => {
    // Regression guard: `closed` must come from the row's own flag, not be
    // inferred from "no usable shifts came out the other end".
    const rows = [
      makeRow({ id: 1, day_of_week: "monday", opens_at: null, closes_at: null, closed: false }),
    ];
    const result = groupBusinessHoursByDay(rows);
    const monday = result.find((d) => d.day === "monday")!;
    expect(monday.closed).toBe(false);
    expect(monday.shifts).toEqual([]);
  });

  it("marks the day closed only when every row for it says closed", () => {
    const rows = [
      makeRow({ id: 1, day_of_week: "monday", opens_at: "12:00:00", closes_at: "15:00:00", closed: false }),
      makeRow({ id: 2, day_of_week: "monday", opens_at: null, closes_at: null, closed: true }),
    ];
    const result = groupBusinessHoursByDay(rows);
    const monday = result.find((d) => d.day === "monday")!;
    expect(monday.closed).toBe(false);
    expect(monday.shifts).toEqual([{ opensAt: "12:00:00", closesAt: "15:00:00" }]);
  });

  it("joins multiple same-day shifts (e.g. lunch + dinner)", () => {
    const rows = [
      makeRow({ id: 1, day_of_week: "friday", opens_at: "12:00:00", closes_at: "15:30:00", closed: false }),
      makeRow({ id: 2, day_of_week: "friday", opens_at: "20:00:00", closes_at: "00:30:00", closed: false }),
    ];
    const result = groupBusinessHoursByDay(rows);
    const friday = result.find((d) => d.day === "friday")!;
    expect(friday.closed).toBe(false);
    expect(friday.shifts).toEqual([
      { opensAt: "12:00:00", closesAt: "15:30:00" },
      { opensAt: "20:00:00", closesAt: "00:30:00" },
    ]);
  });
});

function weekWith(day: DayHours["day"], shifts: DayHours["shifts"]): DayHours[] {
  const days: DayHours["day"][] = [
    "monday",
    "tuesday",
    "wednesday",
    "thursday",
    "friday",
    "saturday",
    "sunday",
  ];
  return days.map((d) => ({ day: d, shifts: d === day ? shifts : [], closed: d !== day }));
}

describe("buildOpeningHoursSpecification", () => {
  it("keeps a same-day shift (no midnight crossing) as a single entry", () => {
    const week = weekWith("monday", [{ opensAt: "08:00:00", closesAt: "20:00:00" }]);
    const entries = buildOpeningHoursSpecification(week);
    expect(entries).toEqual([
      { "@type": "OpeningHoursSpecification", dayOfWeek: "Monday", opens: "08:00", closes: "20:00" },
    ]);
  });

  it("splits an overnight shift crossing midnight into two entries (12:00–00:30)", () => {
    const week = weekWith("monday", [{ opensAt: "12:00:00", closesAt: "00:30:00" }]);
    const entries = buildOpeningHoursSpecification(week);
    expect(entries).toEqual([
      { "@type": "OpeningHoursSpecification", dayOfWeek: "Monday", opens: "12:00", closes: "23:59" },
      { "@type": "OpeningHoursSpecification", dayOfWeek: "Tuesday", opens: "00:00", closes: "00:30" },
    ]);
  });

  it("rolls the second entry onto the correct following day, including Sunday -> Monday", () => {
    const week = weekWith("sunday", [{ opensAt: "19:00:00", closesAt: "03:00:00" }]);
    const entries = buildOpeningHoursSpecification(week);
    expect(entries).toEqual([
      { "@type": "OpeningHoursSpecification", dayOfWeek: "Sunday", opens: "19:00", closes: "23:59" },
      { "@type": "OpeningHoursSpecification", dayOfWeek: "Monday", opens: "00:00", closes: "03:00" },
    ]);
  });

  it("skips the zero-length early-morning entry when the shift closes exactly at midnight", () => {
    const week = weekWith("monday", [{ opensAt: "19:00:00", closesAt: "00:00:00" }]);
    const entries = buildOpeningHoursSpecification(week);
    expect(entries).toEqual([
      { "@type": "OpeningHoursSpecification", dayOfWeek: "Monday", opens: "19:00", closes: "23:59" },
    ]);
  });

  it("produces no entries for a day with no shifts", () => {
    const week = weekWith("monday", []);
    expect(buildOpeningHoursSpecification(week)).toEqual([]);
  });

  it("handles multiple shifts on the same day independently", () => {
    const week = weekWith("friday", [
      { opensAt: "12:00:00", closesAt: "15:30:00" },
      { opensAt: "20:00:00", closesAt: "00:30:00" },
    ]);
    const entries = buildOpeningHoursSpecification(week);
    expect(entries).toEqual([
      { "@type": "OpeningHoursSpecification", dayOfWeek: "Friday", opens: "12:00", closes: "15:30" },
      { "@type": "OpeningHoursSpecification", dayOfWeek: "Friday", opens: "20:00", closes: "23:59" },
      { "@type": "OpeningHoursSpecification", dayOfWeek: "Saturday", opens: "00:00", closes: "00:30" },
    ]);
  });
});
