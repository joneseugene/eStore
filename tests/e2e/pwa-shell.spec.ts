import { expect, test } from "@playwright/test";

test("home page renders and links the manifest", async ({ page }) => {
  await page.goto("/");
  await expect(page.getByRole("heading", { name: "eStore" })).toBeVisible();
  await expect(page.locator('link[rel="manifest"]')).toHaveAttribute(
    "href",
    "/manifest.webmanifest",
  );
});

test("manifest is installable", async ({ request }) => {
  const res = await request.get("/manifest.webmanifest");
  expect(res.ok()).toBe(true);
  const manifest = await res.json();
  expect(manifest.name).toBe("eStore");
  expect(manifest.display).toBe("standalone");
  expect(manifest.icons.length).toBeGreaterThanOrEqual(2);
});

test("service worker is served and registers", async ({ page, request }) => {
  const sw = await request.get("/serwist/sw.js");
  expect(sw.ok()).toBe(true);
  expect(sw.headers()["content-type"]).toContain("javascript");

  await page.goto("/");
  const scope = await page.evaluate(async () => {
    const reg = await navigator.serviceWorker.ready;
    return reg.scope;
  });
  expect(new URL(scope).pathname).toBe("/");
});

test("offline fallback page is reachable", async ({ page }) => {
  await page.goto("/~offline");
  await expect(
    page.getByRole("heading", { name: "You are offline" }),
  ).toBeVisible();
});
