import { Button } from "@/components/ui/button";

/** Placeholder landing page. Replaced by sign-in / org picker in Phase 2. */
export default function Home() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-6 p-6">
      <div className="space-y-2">
        <h1 className="text-3xl font-semibold tracking-tight">eStore</h1>
        <p className="text-muted-foreground">
          Central store and distribution tracking for Ministries, Departments
          and Agencies.
        </p>
      </div>
      <Button size="lg" className="h-12 text-base" disabled>
        Sign in (coming in Phase 2)
      </Button>
    </main>
  );
}
