-- SPEC 07: retira el acceso anónimo a games/scores (SPEC 06), exige sesión.
-- No se edita la migración original (append-only); esta la reemplaza.

drop policy "games_select_all" on public.games;
drop policy "scores_select_all" on public.scores;
drop policy "scores_insert_anon" on public.scores;

create policy "games_select_authenticated" on public.games
  for select to authenticated using (true);

create policy "scores_select_authenticated" on public.scores
  for select to authenticated using (true);

create policy "scores_insert_authenticated" on public.scores
  for insert to authenticated with check (true);

-- RLS por sí sola deja a anon con lista vacía (200 OK), no "permission denied";
-- se revoca el grant de tabla para que la consulta falle de verdad.
revoke all on public.games, public.scores from anon;
