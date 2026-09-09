import { describe, expect, it } from "vitest";
import {
  groupBusinessHoursByDay,
  buildOpeningHoursSpecification,
  getOpenStatus,
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

describe("getOpenStatus", () => {
  // 2024-01-01 was a real, verifiable Monday — every `now` below is built
  // from it (or the days right after) with `new Date(year, month, day,
  // hour, minute)` so the day-of-week math is grounded in an actual
  // calendar, not just an assumption about which index means what.
  const MONDAY = [2024, 0, 1] as const;
  const TUESDAY = [2024, 0, 2] as const;

  it("is open during a same-day shift, closed just before it opens and right at close", () => {
    const week = weekWith("monday", [{ opensAt: "12:00:00", closesAt: "20:00:00" }]);

    expect(getOpenStatus(week, new Date(...MONDAY, 15, 0)).isOpen).toBe(true);
    expect(getOpenStatus(week, new Date(...MONDAY, 12, 0)).isOpen).toBe(true);
    expect(getOpenStatus(week, new Date(...MONDAY, 19, 59)).isOpen).toBe(true);
    expect(getOpenStatus(week, new Date(...MONDAY, 11, 59)).isOpen).toBe(false);
    expect(getOpenStatus(week, new Date(...MONDAY, 20, 0)).isOpen).toBe(false);
  });

  it("is open past midnight on an overnight shift (crosses into the next day)", () => {
    // Monday 19:00–03:00 (Tuesday), same shape as this fixture's real
    // bar/brewery rows (see MOCK_BUSINESS_HOURS, e.g. merchant 3).
    const week = weekWith("monday", [{ opensAt: "19:00:00", closesAt: "03:00:00" }]);

    // Still Monday, after opening — covered by today's own row.
    expect(getOpenStatus(week, new Date(...MONDAY, 23, 0)).isOpen).toBe(true);
    // Already Tuesday, before the shift's real close — covered by
    // *yesterday's* row spilling over, even though Tuesday has no shift.
    expect(getOpenStatus(week, new Date(...TUESDAY, 1, 0)).isOpen).toBe(true);
    expect(getOpenStatus(week, new Date(...TUESDAY, 2, 59)).isOpen).toBe(true);
    // Past the real close — the spillover window is over.
    expect(getOpenStatus(week, new Date(...TUESDAY, 3, 0)).isOpen).toBe(false);
    expect(getOpenStatus(week, new Date(...TUESDAY, 10, 0)).isOpen).toBe(false);
    // Before Monday's own opening.
    expect(getOpenStatus(week, new Date(...MONDAY, 18, 0)).isOpen).toBe(false);
  });

  it("is open past midnight even when the next calendar day is itself marked fully closed", () => {
    // Saturday 18:00–02:00, Sunday closed — exactly this fixture's real
    // shape for several merchants (e.g. merchant 3: Monday closed, every
    // other day 19:00–03:00).
    const days: DayHours["day"][] = [
      "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
    ];
    const week: DayHours[] = days.map((day) =>
      day === "saturday"
        ? { day, shifts: [{ opensAt: "18:00:00", closesAt: "02:00:00" }], closed: false }
        : { day, shifts: [], closed: true },
    );

    // Sunday 01:00 — Saturday's overnight shift is still running.
    const sunday1am = new Date(2024, 0, 7, 1, 0); // 2024-01-07 is a Sunday.
    expect(getOpenStatus(week, sunday1am).isOpen).toBe(true);
    expect(getOpenStatus(week, sunday1am).label).toBe("Abierto ahora");

    // Sunday 10:00 — past the spillover window, and Sunday has no shift of
    // its own.
    const sunday10am = new Date(2024, 0, 7, 10, 0);
    const status = getOpenStatus(week, sunday10am);
    expect(status.isOpen).toBe(false);
    expect(status.label).toBe("Cerrado");
    expect(status.todayLabel).toBe("hoy cerrado");
  });

  it("formats todayLabel from the same formatDayHours the weekly table uses, lowercased and 'hoy'-prefixed", () => {
    const week = weekWith("monday", [{ opensAt: "18:00:00", closesAt: "02:00:00" }]);
    expect(getOpenStatus(week, new Date(...MONDAY, 20, 0)).todayLabel).toBe("hoy 18:00–02:00");
  });

  it("real data — merchant 257 (El Rincón de Gorriti, GET /api/v1/merchants/257 against the running backend): Mon–Sat 18:00–02:00, Sunday closed", () => {
    // Verbatim shape of the real `business_hours` rows returned by the
    // backend for this merchant (see docs/visual-qa-report.md, section 3 —
    // same merchant used for the whole page's visual QA). The API's raw
    // opens_at/closes_at are full ISO timestamps
    // ("2000-01-01T18:00:00.000Z"); `parseTimeOfDay` (lib/api/merchants.ts)
    // already reduces those to the "HH:MM:SS" wall-clock digits used here,
    // so this fixture starts from that already-parsed shape, same as
    // groupBusinessHoursByDay's real input.
    const openDays: BusinessHours["day_of_week"][] = [
      "monday", "tuesday", "wednesday", "thursday", "friday", "saturday",
    ];
    const rows: BusinessHours[] = openDays.map((day, i) =>
      makeRow({ id: i + 1, day_of_week: day, opens_at: "18:00:00", closes_at: "02:00:00", closed: false }),
    );
    rows.push(makeRow({ id: 7, day_of_week: "sunday", opens_at: null, closes_at: null, closed: true }));
    const week = groupBusinessHoursByDay(rows);

    // Wednesday 20:00 — well inside today's own 18:00–02:00 shift.
    const wednesdayEvening = new Date(2024, 0, 3, 20, 0); // 2024-01-03 is a Wednesday.
    expect(getOpenStatus(week, wednesdayEvening)).toEqual({
      isOpen: true,
      label: "Abierto ahora",
      todayLabel: "hoy 18:00–02:00",
    });

    // Wednesday 10:00 — the dead zone: Tuesday's overnight shift already
    // ended at 02:00, today's hasn't started yet at 18:00.
    const wednesdayMorning = new Date(2024, 0, 3, 10, 0);
    expect(getOpenStatus(week, wednesdayMorning)).toEqual({
      isOpen: false,
      label: "Cerrado",
      todayLabel: "hoy 18:00–02:00",
    });

    // Sunday — the day itself is marked fully closed, but Saturday's
    // overnight shift still covers the first two hours of it.
    const sunday1am = new Date(2024, 0, 7, 1, 0);
    expect(getOpenStatus(week, sunday1am).isOpen).toBe(true);
    const sunday3am = new Date(2024, 0, 7, 3, 0);
    expect(getOpenStatus(week, sunday3am)).toEqual({
      isOpen: false,
      label: "Cerrado",
      todayLabel: "hoy cerrado",
    });
  });
});
