import { describe, expect, it } from "vitest";
import { formatDate, formatDateTime, formatQuantity } from "./format";

describe("formatQuantity", () => {
  it("adds thousands separators", () => {
    expect(formatQuantity(1234567)).toBe("1,234,567");
    expect(formatQuantity(0)).toBe("0");
  });

  it("keeps up to two decimals", () => {
    expect(formatQuantity(1500.5)).toBe("1,500.5");
  });
});

describe("formatDateTime", () => {
  it("displays UTC instants in Africa/Freetown (UTC+0, no DST)", () => {
    expect(formatDateTime("2026-11-23T14:05:00Z")).toBe("23 Nov 2026, 14:05");
  });

  it("does not shift the date across midnight", () => {
    expect(formatDate("2026-12-31T23:59:00Z")).toBe("31 Dec 2026");
  });
});
