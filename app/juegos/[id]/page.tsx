import Link from "next/link";
import { notFound } from "next/navigation";
import { GAMES } from "@/lib/data";
import { createClient } from "@/lib/supabase/server";
import { getBestScore, getLeaderboard, type LeaderboardRow } from "@/lib/supabase/scores";

export default async function GameDetailPage({ params }: PageProps<"/juegos/[id]">) {
  const { id } = await params;
  const game = GAMES.find((g) => g.id === id);
  if (!game) notFound();

  const supabase = await createClient();

  let scores: LeaderboardRow[] = [];
  let scoresError = false;
  try {
    scores = await getLeaderboard(supabase, id, 10);
  } catch {
    scoresError = true;
  }

  let bestScore: number | null = null;
  try {
    bestScore = await getBestScore(supabase, id);
  } catch {
    bestScore = null;
  }

  return (
    <div className="av-detail fade-in">
      <div>
        <div className="detail-cover">
          <div className={"cover-bg " + game.cover}></div>
        </div>
        <div style={{ marginTop: 20 }} className="detail-info">
          <div className="detail-tags">
            <span>{game.cat}</span>
            <span>1 JUGADOR</span>
            <span>TECLADO / TÁCTIL</span>
            <span>RETRO 1985</span>
          </div>
          <h2 className="neon-cyan">{game.title}</h2>
          <p>{game.long}</p>
          <div className="stat-strip">
            <div>
              <div className="l">Partidas</div>
              <div className="v">{game.plays}</div>
            </div>
            <div>
              <div className="l">Mejor global</div>
              <div
                className="v"
                style={{ color: "var(--magenta)", textShadow: "0 0 6px rgba(255,0,110,0.5)" }}
              >
                {bestScore !== null ? bestScore.toLocaleString("es-ES") : "—"}
              </div>
            </div>
            <div>
              <div className="l">Dificultad</div>
              <div
                className="v"
                style={{ color: "var(--yellow)", textShadow: "0 0 6px rgba(245,255,0,0.5)" }}
              >
                ★ ★ ★ ☆ ☆
              </div>
            </div>
          </div>
          <div className="detail-actions">
            <Link href={`/juegos/${game.id}/jugar`} className="btn xl pulse">
              ▶ JUGAR AHORA
            </Link>
            <Link href="/biblioteca" className="btn ghost lg">
              VOLVER AL VAULT
            </Link>
          </div>
        </div>
      </div>

      <aside>
        <div className="leaderboard">
          <h3>MEJORES PUNTUACIONES</h3>
          {scoresError ? (
            <p className="mono" style={{ color: "var(--magenta)", fontSize: 12 }}>
              NO SE PUDO CARGAR EL LEADERBOARD. INTENTA MÁS TARDE.
            </p>
          ) : (
            scores.map((r, i) => (
              <div
                key={r.rank}
                className={"lb-row" + (i === 0 ? " top1" : i === 1 ? " top2" : i === 2 ? " top3" : "")}
              >
                <div className="rk">#{String(r.rank).padStart(2, "0")}</div>
                <div className="pl">
                  {r.name}
                  <div style={{ fontSize: 10, color: "var(--ink-faint)", letterSpacing: "0.1em" }}>
                    {r.date}
                  </div>
                </div>
                <div className="sc">{r.score.toLocaleString("es-ES")}</div>
              </div>
            ))
          )}
        </div>
      </aside>
    </div>
  );
}
