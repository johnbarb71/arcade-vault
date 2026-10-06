// Next.js only inlines NEXT_PUBLIC_* vars into the browser bundle when they are
// accessed literally, so each one is read by name instead of via process.env[key].
export function getSupabaseEnv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const publishableKey = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

  if (!url) {
    throw new Error("Missing environment variable NEXT_PUBLIC_SUPABASE_URL");
  }
  if (!publishableKey) {
    throw new Error(
      "Missing environment variable NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY",
    );
  }

  return { url, publishableKey };
}
