import { z } from "zod";

/**
 * Public environment, safe for the browser. The service role key is never
 * read here and must never be prefixed with NEXT_PUBLIC_.
 *
 * NEXT_PUBLIC_* values are inlined at build time, so they must be referenced
 * literally (not via process.env[name]).
 */
const schema = z.object({
  supabaseUrl: z.url(),
  supabasePublishableKey: z.string().min(1),
});

export const env = schema.parse({
  supabaseUrl: process.env.NEXT_PUBLIC_SUPABASE_URL,
  supabasePublishableKey: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
});
