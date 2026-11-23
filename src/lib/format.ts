/** Display formatting shared across the app. Times are stored in UTC. */

export const APP_TIME_ZONE = "Africa/Freetown";

const quantityFormatter = new Intl.NumberFormat("en-GB", {
  maximumFractionDigits: 2,
});

/** 12500 → "12,500" */
export function formatQuantity(value: number): string {
  return quantityFormatter.format(value);
}

const dateTimeFormatter = new Intl.DateTimeFormat("en-GB", {
  timeZone: APP_TIME_ZONE,
  day: "2-digit",
  month: "short",
  year: "numeric",
  hour: "2-digit",
  minute: "2-digit",
  hour12: false,
});

const dateFormatter = new Intl.DateTimeFormat("en-GB", {
  timeZone: APP_TIME_ZONE,
  day: "2-digit",
  month: "short",
  year: "numeric",
});

/** UTC ISO string or Date → "23 Nov 2026, 14:05" in Freetown time. */
export function formatDateTime(value: string | Date): string {
  return dateTimeFormatter.format(new Date(value));
}

/** UTC ISO string or Date → "23 Nov 2026" in Freetown time. */
export function formatDate(value: string | Date): string {
  return dateFormatter.format(new Date(value));
}
