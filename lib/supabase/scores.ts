import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";

export interface LeaderboardRow {
  rank: number;
  name: string;
  score: number;
  date: string; // DD/MM/YYYY, derivado de created_at
}

function formatDate(isoDate: string): string {
  const d = new Date(isoDate);
  const day = String(d.getDate()).padStart(2, "0");
  const month = String(d.getMonth() + 1).padStart(2, "0");
  return `${day}/${month}/${d.getFullYear()}`;
}

export async function getLeaderboard(
  supabase: SupabaseClient<Database>,
  gameId: string,
  limit: number,
): Promise<LeaderboardRow[]> {
  const { data, error } = await supabase
    .from("scores")
    .select("name, score, created_at")
    .eq("game_id", gameId)
    .order("score", { ascending: false })
    .limit(limit);

  if (error) throw new Error(error.message);

  return data.map((row, i) => ({
    rank: i + 1,
    name: row.name,
    score: row.score,
    date: formatDate(row.created_at),
  }));
}

export async function getBestScore(
  supabase: SupabaseClient<Database>,
  gameId: string,
): Promise<number | null> {
  const { data, error } = await supabase
    .from("scores")
    .select("score")
    .eq("game_id", gameId)
    .order("score", { ascending: false })
    .limit(1)
    .maybeSingle();

  if (error) throw new Error(error.message);

  return data?.score ?? null;
}

export async function saveScore(
  supabase: SupabaseClient<Database>,
  gameId: string,
  name: string,
  score: number,
): Promise<{ ok: true } | { ok: false; error: string }> {
  try {
    const { error } = await supabase
      .from("scores")
      .insert({ game_id: gameId, name, score });

    if (error) throw new Error(error.message);

    return { ok: true };
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    return { ok: false, error: message };
  }
}
