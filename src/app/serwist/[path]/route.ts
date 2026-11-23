import { spawnSync } from "node:child_process";
import { createSerwistRoute } from "@serwist/turbopack";

// Revision for non-hashed precache entries (the offline page). Changes on
// every deploy so installed apps pick up a new offline page.
const revision =
  process.env.VERCEL_GIT_COMMIT_SHA ||
  spawnSync("git", ["rev-parse", "HEAD"], {
    encoding: "utf-8",
  }).stdout?.trim() ||
  crypto.randomUUID();

const route = createSerwistRoute({
  swSrc: "src/app/sw.ts",
  // Native esbuild is installed; esbuild-wasm (the non-Windows default) is not.
  useNativeEsbuild: true,
  additionalPrecacheEntries: [{ url: "/~offline", revision }],
});

// Only GET and generateStaticParams are re-exported: with Cache Components
// enabled, route segment config exports (dynamic, revalidate, dynamicParams)
// are not allowed. The handler reads no request data, so it prerenders.
export const { GET, generateStaticParams } = route;
