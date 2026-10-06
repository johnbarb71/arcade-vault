-- Health check: RPC trivial para comprobar URL, clave y permisos de anon (SPEC 04).
create or replace function public.health_check()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$ select true $$;

grant execute on function public.health_check() to anon, authenticated;
