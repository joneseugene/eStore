"use client";

import { SerwistProvider } from "@serwist/turbopack/react";
import type { ReactNode } from "react";

/**
 * Registers the service worker in production only (dev uses NetworkOnly
 * anyway, and a dev SW makes debugging confusing).
 *
 * reloadOnOnline is off: an automatic reload when the connection returns
 * would wipe half-filled forms. The offline queue syncs on its own instead.
 */
export function PwaProvider({ children }: { children: ReactNode }) {
  return (
    <SerwistProvider
      swUrl="/serwist/sw.js"
      disable={process.env.NODE_ENV !== "production"}
      reloadOnOnline={false}
    >
      {children}
    </SerwistProvider>
  );
}
