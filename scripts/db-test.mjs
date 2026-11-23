// Runs the pgTAP files in supabase/tests against the hosted database via psql.
// `supabase test db` needs Docker even for remote targets; this does not.
// Each test file wraps itself in BEGIN ... ROLLBACK, so nothing persists.
//
// Needs in .env.local (or the environment):
//   NEXT_PUBLIC_SUPABASE_URL   https://<ref>.supabase.co
//   SUPABASE_DB                database password
//   SUPABASE_POOLER_HOST       optional, default aws-0-eu-west-1.pooler.supabase.com
//   PSQL                       optional path to psql, default "psql"
import { spawnSync } from "node:child_process";
import { existsSync, readdirSync } from "node:fs";
import path from "node:path";

if (existsSync(".env.local")) process.loadEnvFile(".env.local");

const ref = new URL(process.env.NEXT_PUBLIC_SUPABASE_URL ?? "").hostname.split(
  ".",
)[0];
const password = process.env.SUPABASE_DB;
if (!ref || !password) {
  console.error(
    "Set NEXT_PUBLIC_SUPABASE_URL and SUPABASE_DB (database password).",
  );
  process.exit(2);
}

const host =
  process.env.SUPABASE_POOLER_HOST ?? "aws-0-eu-west-1.pooler.supabase.com";
const conn = `host=${host} port=5432 dbname=postgres user=postgres.${ref} sslmode=require`;
const dir = "supabase/tests";
const files = readdirSync(dir)
  .filter((f) => f.endsWith(".sql"))
  .sort();

let failed = false;
for (const file of files) {
  const result = spawnSync(
    process.env.PSQL ?? "psql",
    [
      conn,
      "-X",
      "-q",
      "-t",
      "-A",
      "-v",
      "ON_ERROR_STOP=1",
      "-f",
      path.join(dir, file),
    ],
    { encoding: "utf-8", env: { ...process.env, PGPASSWORD: password } },
  );
  const lines = `${result.stdout}`
    .split(/\r?\n/)
    .filter((l) => /^(ok|not ok|1\.\.|#)/.test(l));
  const planned = Number(
    lines.find((l) => l.startsWith("1.."))?.slice(3) ?? NaN,
  );
  const passed = lines.filter((l) => l.startsWith("ok")).length;
  const failures = lines.filter(
    (l) => l.startsWith("not ok") || l.startsWith("#"),
  );

  console.log(`\n${file}: ${passed}/${planned} passed`);
  for (const l of failures) console.log(`  ${l}`);
  if (result.status !== 0) console.log(result.stderr.trim());
  if (
    result.status !== 0 ||
    passed !== planned ||
    failures.some((l) => l.startsWith("not ok"))
  ) {
    failed = true;
  }
}

process.exit(failed ? 1 : 0);
