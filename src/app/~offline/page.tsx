import type { Metadata } from "next";

export const metadata: Metadata = { title: "Offline" };

/**
 * Served by the service worker when a page is requested with no network and
 * no cached copy. Must stay fully static so it can be precached.
 */
export default function OfflinePage() {
  return (
    <main className="mx-auto flex min-h-dvh max-w-md flex-col justify-center gap-4 p-6">
      <h1 className="text-2xl font-semibold">You are offline</h1>
      <p className="text-muted-foreground">
        This page has not been saved on this device yet. Pages you have opened
        before still work offline, and any actions you record will sync when you
        reconnect.
      </p>
    </main>
  );
}
