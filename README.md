# eStore

Multi-tenant PWA for Ministries, Departments and Agencies to manage a central store and trace goods down their hierarchy to end points. First tenant: MBSSE (National Store → DEOs → Schools).

See [CLAUDE.md](CLAUDE.md) for the build brief and [DECISIONS.md](DECISIONS.md) for design decisions.

## Stack

Next.js 16 (App Router, Turbopack, Cache Components) · TypeScript strict · Supabase (Postgres, Auth, RLS, Storage) · Tailwind 4 + shadcn/ui · React Hook Form + Zod · Serwist (service worker) · Dexie (offline queue) · Vitest · Playwright · pgTAP

## Setup

Requires Node 24+ and npm.

```bash
npm install
cp .env.example .env.local   # then fill in values from Supabase → Project Settings → API
npx playwright install chromium
```

Link the Supabase CLI to the hosted project (one-off; prompts for the database password):

```bash
npx supabase login
npx supabase link --project-ref <project-ref>
```

## Scripts

| Command | What it does |
| --- | --- |
| `npm run dev` | Dev server on http://localhost:3000 (service worker disabled) |
| `npm run build && npm start` | Production build; the service worker is active here |
| `npm run lint` / `npm run typecheck` | ESLint / TypeScript |
| `npm run format` | Prettier (with Tailwind class sorting) |
| `npm test` | Vitest unit tests |
| `npm run test:e2e` | Playwright (builds and serves on port 3100) |
| `npm run db:push` | Apply `supabase/migrations` to the linked project |
| `npm run db:types` | Regenerate `src/types/database.ts` from the linked project |
| `npm run db:test` | pgTAP tests in `supabase/tests` against the linked project |

`db:push` changes the hosted database. Review migrations before running it.

## Windows note

Run commands from a path that starts with an uppercase `C:\`. If the working directory is `c:\…` (lowercase), Vitest loads two copies of itself and every test file fails with `Cannot read properties of undefined (reading 'config')`.

## Testing the PWA

The service worker only registers in production builds. Run `npm run build && npm start`, open Chrome DevTools → Application → Service workers, then tick Network → Offline and reload: visited pages still load, and unvisited ones show the `/~offline` page.
