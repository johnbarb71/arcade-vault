# SPEC 08 — Endurecimiento de seguridad (headers, RLS y configuración de Auth)

> **Estado:** Implementado
> **Depende de:** SPEC 01, SPEC 04, SPEC 06, SPEC 07
> **Fecha:** 2026-10-14
> **Objetivo:** Cerrar los puntos del checklist de seguridad (`references/Security/Checklist.md`): vincular `scores` a `auth.users` para que el INSERT ya no sea `WITH CHECK (true)`, revocar `EXECUTE` de `anon`/`authenticated` sobre la función de plataforma `rls_auto_enable()`, agregar los 3 headers de seguridad de Next.js, y documentar la configuración manual de Supabase Auth (contraseña mínima de 8 caracteres, protección de contraseñas filtradas, rate limit de sign-ups por IP).

---

## Por qué existe este spec

`references/Security/Checklist.md` lista 5 puntos básicos de seguridad más una tabla de warnings reales tomada del panel de advisors de Supabase. RLS ya está habilitado en `games` y `scores` desde SPEC 06/07, pero el panel de advisors (confirmado en vivo con `get_advisors(type: "security")` y una consulta directa a `pg_policy`) sigue marcando tres problemas reales:

1. `scores_insert_authenticated` (SPEC 07) tiene `WITH CHECK (true)`: cualquier usuario autenticado puede insertar una fila a nombre de cualquier `name`/`score`, sin ningún vínculo con su propia cuenta. SPEC 07 difirió explícitamente "vincular `scores` a `auth.users`" a un spec futuro — este es ese spec, acotado solo a la columna y la policy, no a la UI que podría construirse sobre ella.
2. `public.rls_auto_enable()` es una función `SECURITY DEFINER` que no existe en ninguna de nuestras migraciones — es infraestructura que Supabase agrega a proyectos nuevos (un event trigger que auto-activa RLS en tablas nuevas) — y el advisor la marca como ejecutable por `anon` y `authenticated`.
3. "Leaked password protection" está desactivado en el proyecto.

El resto del checklist (longitud mínima de contraseña, rate limit de sign-ups por IP, headers de seguridad en Next.js) no tiene ningún código ni configuración todavía. Este spec cierra los 5 puntos del checklist y los 3 warnings confirmados del panel de advisors, sin reabrir nada más de lo que SPEC 07 dejó fuera de alcance (tabla `profiles`, reset de contraseña, SMTP propio, destacar "tu mejor marca").

---

## Scope

**In:**

- Migración `supabase/migrations/20261014010000_scores_security_hardening.sql`:
  - `alter table public.scores add column user_id uuid references auth.users(id) default auth.uid();` — columna nullable, sin backfill de las 96 filas semilla de SPEC 06.
  - Reemplaza la policy `scores_insert_authenticated` (SPEC 07) por `scores_insert_own`, que exige `with check (auth.uid() = user_id)` para `INSERT` a `authenticated`.
  - `revoke execute on function public.rls_auto_enable() from anon, authenticated;`.
  - Regenerar `lib/supabase/database.types.ts` con `generate_typescript_types`.
- `next.config.ts`: agregar el array `securityHeaders` y una función `headers()` que aplica `X-Content-Type-Options`, `X-Frame-Options` y `Referrer-Policy` (los 3 headers literales del ejemplo del checklist) a `/(.*)`.
- Configuración manual en el dashboard de Supabase (documentada en el plan y en `README.md`, mismo patrón que SPEC 07 usó para "Confirm email" y las credenciales OAuth):
  - Longitud mínima de contraseña = 8 caracteres.
  - Activar "Leaked password protection".
  - Protección de rutas con Proxy Next JS.
  - Confirmar/ajustar el rate limit nativo de sign-ups por IP (Authentication > Rate Limits).
- Verificación con `get_advisors(type: "security")` tras los cambios de que los 3 warnings confirmados ya no aparecen.
- Documentar en `README.md` y `CLAUDE.md`: la columna `scores.user_id`, la policy `scores_insert_own`, los 3 pasos manuales de Auth, y los headers nuevos.

**Out of scope (para specs futuros):**

- Backfill de las 96 filas semilla de SPEC 06 con un usuario real: quedan con `user_id = null` permanentemente.
- Cualquier UI que lea o muestre `user_id` (destacar "tu mejor marca", resaltar filas propias en Detalle o Salón de la Fama). La columna y la policy se agregan solo para cerrar el warning de seguridad.
- `Strict-Transport-Security`, `Permissions-Policy`, `Content-Security-Policy` o cualquier header fuera de los 3 literales del checklist.
- Rate limiting o CAPTCHA propio (código) para el signup — se usa exclusivamente el nativo de Supabase Auth.
- Reset de contraseña, SMTP propio, tabla `profiles`, roles o permisos diferenciados — siguen diferidos de SPEC 07, sin reabrirse aquí.
- Cualquier otro warning de `get_advisors` que no esté explícitamente listado en este spec (si aparece uno nuevo después de aplicar los cambios, se evalúa en un spec futuro).

---

## Modelo de datos

```sql
-- supabase/migrations/20261014010000_scores_security_hardening.sql

alter table public.scores
  add column user_id uuid references auth.users(id) default auth.uid();

drop policy "scores_insert_authenticated" on public.scores;

create policy "scores_insert_own" on public.scores
  for insert to authenticated
  with check (auth.uid() = user_id);

revoke execute on function public.rls_auto_enable() from anon, authenticated;
```

Convenciones:

- `user_id` es nullable: las 96 filas semilla de SPEC 06 quedan con `user_id = null` (no hay cuenta real a la que atribuirlas) y siguen siendo legibles por cualquier `authenticated` — la policy de `SELECT` (SPEC 07) no cambia.
- Toda fila nueva insertada vía `saveScore()` recibe `user_id = auth.uid()` automáticamente por el `default` de la columna; el cliente nunca envía ese valor, así que no puede falsificarlo.
- `lib/supabase/scores.ts` no cambia de firma: `saveScore(supabase, gameId, name, score)` sigue igual. `name` sigue siendo texto libre prellenado con el username (SPEC 07), sin relación de unicidad con `user_id`.
- `games_select_authenticated` y `scores_select_authenticated` (SPEC 07) no se tocan.

---

## Plan de implementación

1. Crear y aplicar `supabase/migrations/20261014010000_scores_security_hardening.sql` (columna `user_id`, policy `scores_insert_own`, revoke de `rls_auto_enable`). Regenerar `lib/supabase/database.types.ts`. Verificación: `list_migrations` la muestra; `select column_name from information_schema.columns where table_name = 'scores'` incluye `user_id`; una consulta a `pg_policy` muestra `scores_insert_own` con `with_check = (auth.uid() = user_id)`.
2. Agregar `securityHeaders` y `headers()` en `next.config.ts` con los 3 headers del checklist sobre `/(.*)`. Verificación: `npm run build` pasa; con el server corriendo, las respuestas incluyen `X-Content-Type-Options`, `X-Frame-Options` y `Referrer-Policy` (revisar con devtools o `curl -I`).
3. En el dashboard de Supabase (Authentication > Policies), activar longitud mínima de contraseña = 8 y "Leaked password protection". Verificación manual: crear una cuenta con contraseña de 5 caracteres falla con el mensaje de Supabase; `get_advisors(type: "security")` deja de listar `auth_leaked_password_protection`.
4. En el dashboard de Supabase (Authentication > Rate Limits), confirmar o ajustar el límite de sign-ups por IP. Verificación manual: el valor configurado se refleja en la pantalla de configuración del proyecto; documentar el valor final en el paso 6.
5. Ejecutar `get_advisors(type: "security")` de nuevo y confirmar que los warnings de `rls_auto_enable` (`anon_security_definer_function_executable`, `authenticated_security_definer_function_executable`) y `auth_leaked_password_protection` ya no aparecen. Jugar una partida logueado y guardar puntuación: confirmar con `execute_sql` que la fila nueva tiene `user_id` igual al id del usuario autenticado, y que las filas semilla siguen con `user_id null` sin romper el leaderboard de Detalle ni el Salón de la Fama.
6. Aplicar protección de rutas con Proxy Next JS.
7. Documentar en `README.md` (columna `user_id`, policy `scores_insert_own`, los 3 pasos manuales de Auth con el valor final del rate limit, los 3 headers) y actualizar `CLAUDE.md`. Verificación: `npm run build` y `npm run lint` pasan.

---

## Criterios de aceptación

- [x] `scores` tiene una columna `user_id uuid` nullable, con `default auth.uid()` y FK a `auth.users(id)`.
- [x] La policy de `INSERT` en `scores` es `scores_insert_own` y exige `auth.uid() = user_id` (ya no `with check (true)`).
- [x] Guardar una puntuación logueado inserta una fila con `user_id` igual al id de la sesión actual, sin que el Reproductor lo envíe explícitamente. (Probado en vivo: partida de Rocas con score 20, fila `id=99` con `user_id` = id de la sesión autenticada.)
- [x] Las 96 filas semilla de SPEC 06 siguen existiendo con `user_id = null` y siguen apareciendo en Detalle/Salón de la Fama sin cambios visuales.
- [x] `EXECUTE` sobre `public.rls_auto_enable()` está revocado para `anon` y `authenticated`.
- [x] `next.config.ts` agrega `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` y `Referrer-Policy: strict-origin-when-cross-origin` a todas las rutas.
- [x] En el dashboard de Supabase, la longitud mínima de contraseña es 8 (con un requisito de complejidad adicional que el dashboard activó junto a esto). "Leaked password protection" **no** se pudo activar: requiere el plan Pro de Supabase, que este proyecto no tiene. Limitación aceptada explícitamente por el usuario; documentada en `README.md`, pendiente de cuando el proyecto tenga un plan compatible.
- [x] El rate limit de sign-ups por IP en el dashboard de Supabase está confirmado en 30/hora (valor por defecto) y documentado en `README.md`.
- [x] `get_advisors(type: "security")` ya no reporta `rls_policy_always_true` en `scores`, ni `anon_security_definer_function_executable`/`authenticated_security_definer_function_executable` para `rls_auto_enable`. `auth_leaked_password_protection` **sigue apareciendo** — misma limitación de plan, aceptada y documentada.
- [x] `npm run build` y `npm run lint` pasan sin errores.

---

## Decisiones

- **Sí:** vincular `scores` a `auth.users` ahora mediante `user_id`, aunque SPEC 07 lo había diferido explícitamente. Decisión explícita del usuario al revisar el warning "RLS Policy Always True": arreglarlo de raíz requiere el vínculo; se reabre solo esa pieza puntual (columna + policy), no el resto de lo diferido en SPEC 07.
- **Sí:** `user_id` nullable con `default auth.uid()`, en vez de backfillear las 96 filas semilla con una cuenta placeholder. Evita inventar un usuario ficticio solo para satisfacer una constraint `NOT NULL`.
- **Sí:** `user_id` se resuelve con el `default` de la columna, nunca lo envía el cliente. Evita que alguien falsifique el insert pasando el `user_id` de otra persona — el valor sale del JWT de la request, no de un parámetro controlado por el cliente.
- **No:** ninguna pantalla lee o muestra `user_id` todavía (ni "tu mejor marca", ni resaltar filas propias). Decisión explícita del usuario: este spec es de endurecimiento de seguridad, no de features de UI nuevas; eso sigue diferido, igual que decía SPEC 07.
- **Sí:** revocar `EXECUTE` de `anon`/`authenticated` sobre `rls_auto_enable()` vía migración, aunque la función la agrega la plataforma Supabase y no nuestras migraciones. Es seguro — la función no toma argumentos y retorna `event_trigger`, no se puede invocar como RPC normal de todas formas — y cierra el warning sin tocar su lógica.
- **Sí:** exactamente los 3 headers literales del ejemplo del checklist (`X-Content-Type-Options`, `X-Frame-Options`, `Referrer-Policy`), sin `Strict-Transport-Security`, `Permissions-Policy` ni `Content-Security-Policy`. Decisión explícita del usuario: ampliar el set o agregar CSP queda para un spec futuro, para no arriesgar romper algo (Google Fonts, OAuth redirects) sin mapear cada fuente externa primero.
- **Sí:** contraseña mínima de 8 caracteres, leaked password protection y el rate limit de sign-ups por IP se configuran manualmente en el dashboard de Supabase y se documentan como pasos manuales — mismo patrón que SPEC 07 usó para "Confirm email" y las credenciales OAuth. No existe una herramienta MCP para fijar esta configuración de Auth por código.
- **No:** un rate limiter propio en código (API route con conteo por IP) para los sign-ups. Decisión explícita del usuario: usar el nativo de Supabase Auth en vez de construir y mantener esa pieza de infraestructura.

---

## Riesgos

| Riesgo                                                                                                                                                                       | Mitigación                                                                                                                                                                                                                                      |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Las 96 filas semilla quedan con `user_id = null` permanentemente; un spec futuro que asuma que toda fila tiene dueño (p. ej. para "tu mejor marca") deberá manejar ese caso. | Aceptado y documentado explícitamente: cualquier feature futura sobre `user_id` debe tolerar `null`.                                                                                                                                            |
| Revocar `EXECUTE` sobre `rls_auto_enable()` — función gestionada por la plataforma Supabase, no por nuestras migraciones — podría comportarse distinto a lo esperado.        | Se verifica con `get_advisors` y creando una tabla de prueba tras el revoke que RLS sigue auto-activándose (el trigger corre como su owner, no como `anon`/`authenticated`); reversible con un `grant` en una migración nueva si algo se rompe. |
| Los pasos manuales en el dashboard de Supabase (password policy, leaked password protection, rate limit) no se pueden verificar con `npm run build` ni con Playwright.       | El plan incluye verificación manual explícita en cada paso (contraseña corta, revisar `get_advisors`) antes de pasar al siguiente.                                                                                                              |
| Un insert a `scores` fuera de la app (script o `execute_sql` directo) sin pasar por una request autenticada no tiene `auth.uid()` disponible para el `default`.              | Aceptado: cualquier insert manual fuera de la app debe fijar `user_id` explícitamente o usar un rol que bypasee RLS (igual que la siembra por migración en SPEC 06).                                                                            |

---

## Lo que **no** está en este spec

- Backfill de las 96 filas semilla con un usuario real.
- Cualquier UI que lea o muestre `user_id` (destacar "tu mejor marca", resaltar filas propias).
- `Strict-Transport-Security`, `Permissions-Policy`, `Content-Security-Policy` u otros headers fuera de los 3 del checklist.
- Rate limiting o CAPTCHA propio en el signup (se usa el nativo de Supabase Auth).
- Reset de contraseña, SMTP propio, tabla `profiles`, roles — siguen diferidos de SPEC 07.
- Cualquier otro warning de `get_advisors` no listado explícitamente en este spec.

Cada uno de estos, si se implementa, va en su propio spec.
