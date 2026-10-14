-- SPEC 08: vincula scores a auth.users y cierra warnings de advisors.
-- No se edita ninguna migración anterior (append-only); esta las complementa.

alter table public.scores
  add column user_id uuid references auth.users(id) default auth.uid();

drop policy "scores_insert_authenticated" on public.scores;

create policy "scores_insert_own" on public.scores
  for insert to authenticated
  with check (auth.uid() = user_id);

revoke execute on function public.rls_auto_enable() from anon, authenticated;
-- anon/authenticated heredan EXECUTE de PUBLIC; sin este revoke el anterior no tiene efecto.
revoke execute on function public.rls_auto_enable() from public;
