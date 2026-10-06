import { createClient } from "@/lib/supabase/server";

type HealthResponse = { ok: true } | { ok: false; error: string };

export async function GET() {
  try {
    const supabase = await createClient();
    const { data, error } = await supabase.rpc("health_check");

    if (error) throw new Error(error.message);
    if (data !== true) throw new Error("health_check did not return true");

    return Response.json({ ok: true } satisfies HealthResponse);
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return Response.json(
      { ok: false, error: message } satisfies HealthResponse,
      {
        status: 503,
      },
    );
  }
}
