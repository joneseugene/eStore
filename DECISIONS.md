# Decisions

A running log of design choices not fixed by the build brief. Newest phase last.

## Phase 0 — Project setup (2026-11-23)

**D-001 Package name `estore`.** npm forbids capitals in package names. "eStore" is the display name (manifest, UI).

**D-002 Hosted Supabase, Vercel.** The hosted Supabase project is the database for development and production until we add a separate staging project. Migrations live in `supabase/migrations` and are applied with `supabase db push` after `supabase link`. Pushing to the hosted project is always a deliberate, confirmed step. Local Supabase (Docker) is optional and not required.

**D-003 Keep Cache Components and Partial Prefetching on.** These are the `create-next-app` defaults for Next 16. Consequence: any component that reads the Supabase session (cookies) must render inside `<Suspense>`, and layouts must not `await` the session at the top level. In return, prefetched app shells render during offline soft navigation, which helps the low-connectivity requirement. If this friction outweighs the benefit, routes can opt out with `export const instant = false`.

**D-004 `proxy.ts`, not `middleware.ts`.** Next 16 renamed Middleware to Proxy. The proxy only refreshes the Supabase session. It is not an authorization layer; RLS and server actions are.

**D-005 Supabase publishable key.** Clients use `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (the newer `sb_publishable_…` key; the legacy anon key also works). The secret/service key is only for server-side seed and admin scripts and is never imported by app code.

**D-006 Serwist via `@serwist/turbopack`.** Next 16 builds with Turbopack. Serwist's Turbopack integration builds the service worker with esbuild and serves it from a route handler, so we keep Turbopack for dev and build.

**D-007 Offline layers.** Two complementary mechanisms:
1. Serwist service worker: precaches the app shell and the `/~offline` fallback, so the installed app opens with no network.
2. Dexie (IndexedDB) action queue (Phase 6): offline-capable mutations are stored with their idempotency key and replayed by the client when back online.
Next's experimental `useOffline` retries pending navigations and Server Actions, but it does not survive a page reload, so it is not used as the queue.

**D-008 Test tooling.** Vitest for unit tests (allocation math), Playwright for one happy-path E2E per phase, and pgTAP via `supabase test db` for RLS and stock-function tests.

**D-009 `@types/node` ^24.** Matches the Node 24 runtime and satisfies Vitest's peer requirement.

**D-011 shadcn/ui on Radix primitives.** Chosen over Base UI as the longer-established option. shadcn now uses its own `cn` package (shadcn-ui/cn) in place of clsx + tailwind-merge.

**D-012 Service worker never caches Supabase traffic.** A `NetworkOnly` rule for `*.supabase.co` comes before Serwist's default cache. Same-origin pages and RSC payloads are cached `NetworkFirst` for offline viewing; Phase 2 must clear these caches on sign-out, because devices may be shared.

**D-013 No auto-reload on reconnect.** Serwist's `reloadOnOnline` is disabled, so regaining a connection doesn't wipe a half-completed form.

**D-010 Folder layout.**
```
src/
  app/
    (auth)/            sign-in etc.
    (app)/[org]/       tenant-scoped feature folders (dispatches, allocation, …)
    ~offline/          service-worker fallback page
    serwist/           route handler serving the service worker
  components/ui/       shadcn/ui primitives
  components/          shared app components
  lib/supabase/        server, browser and proxy clients
  lib/                 env, formatting, shared utilities
  types/database.ts    generated Supabase types
supabase/
  migrations/          SQL migrations
  tests/               pgTAP tests
  seed.sql
tests/e2e/             Playwright
```
