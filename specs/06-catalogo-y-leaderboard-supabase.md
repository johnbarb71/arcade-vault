# SPEC 06 — Tabla de juegos y leaderboard real en Supabase

> **Estado:** Aprobado
> **Depende de:** SPEC 01, SPEC 04
> **Fecha:** 2026-10-06
> **Objetivo:** Crear las tablas `games` y `scores` en Supabase (con datos semilla equivalentes a `lib/data.ts` y `seededScores`), reemplazar el guardado de puntuaciones del Reproductor en `localStorage` por un insert real a `scores`, y conectar a esa misma tabla el leaderboard lateral de Detalle y el Salón de la Fama — sin migrar todavía el catálogo visual (Biblioteca, Detalle y Salón siguen leyendo `GAMES` de `lib/data.ts` para portada/tags/descripción de cada juego).

---

## Por qué existe este spec

SPEC 04 dejó la infraestructura de Supabase lista (clientes tipados, migraciones versionadas, health check) pero dejó explícitamente fuera de alcance "cualquier tabla de dominio (`games`, `scores`, `profiles`…) y migrar el catálogo" y "persistencia de puntuaciones". SPEC 05 portó el primer juego real (Rocas/Asteroids) pero mantuvo el guardado de puntuación igual que SPEC 01: una entrada en `localStorage["av_scores"]` que nunca se vuelve a leer.

Hoy todo el "leaderboard" de la app es `seededScores(seed, count)`: un PRNG determinista que genera filas falsas distintas según quién lo llama — el Detalle usa `seededScores(id.length * 17 + 3, 10)` y el Salón de la Fama usa `seededScores(tab.length * 23 + 7, 12)`, dos semillas distintas para el mismo juego. Nada de lo que un jugador realmente puntúa aparece nunca en esas pantallas.

Este spec cierra ese hueco: dos tablas nuevas en Supabase, una única fuente real de puntuaciones que alimenta Detalle y Salón de la Fama, y el Reproductor empieza a escribir ahí en vez de en `localStorage`. El catálogo de juegos (textos, portadas, categorías) sigue siendo mock en esta pasada — se crea y siembra la tabla `games` por completitud y para que un spec futuro solo tenga que conectar pantallas, igual que hizo SPEC 04 con la infraestructura base.

---

## Scope

**In:**

- Migración SQL `supabase/migrations/20261006000000_games_and_scores.sql`:
  - Tabla `public.games` con las mismas columnas que la interfaz `Game` de `lib/data.ts` (`id` texto como PK, `title`, `short`, `long`, `cat`, `cover`, `color`, `best`, `plays`), sembrada con los 8 juegos de `GAMES` tal cual.
  - Tabla `public.scores` (`id` identity PK, `game_id` texto con FK a `games(id)`, `name` texto, `score` entero, `created_at timestamptz` default `now()`), con índice `(game_id, score desc)`.
  - Datos semilla en `scores`: 12 filas por juego (96 en total), generadas una sola vez con la misma lógica de `seededScores(gameId.length * 23 + 7, 12)` que hoy usa el Salón de la Fama, embebidas como `INSERT` literales en la migración (no se ejecuta JS en Supabase). Esto unifica lo que hoy eran dos semillas distintas (Detalle y Salón) en una sola tabla de la que ambas pantallas leen subconjuntos.
  - RLS habilitada en ambas tablas: `SELECT` abierto a `anon`/`authenticated` en `games` y `scores`; `INSERT` abierto a `anon`/`authenticated` en `scores` sin checks adicionales (ni `UPDATE` ni `DELETE` para nadie).
- Regenerar `lib/supabase/database.types.ts` con `generate_typescript_types` tras aplicar la migración.
- `lib/supabase/scores.ts`: funciones `getLeaderboard`, `getBestScore`, `saveScore` (ver Modelo de datos), que reciben el cliente de Supabase (server o browser) como parámetro para ser usables tanto desde componentes server como client.
- `app/juegos/[id]/jugar/page.tsx`: `saveScore()` deja de escribir en `localStorage["av_scores"]` y pasa a llamar al helper `saveScore(supabase, game.id, name, score)` con el cliente browser, para **los 8 juegos** (no solo Rocas). Si falla, se muestra un error visible en el modal en vez de fingir éxito.
- `app/juegos/[id]/page.tsx` (server component): el leaderboard lateral y el stat "mejor global" dejan de usar `seededScores`/`game.best` y pasan a usar `getLeaderboard(supabase, id, 10)` / `getBestScore(supabase, id)` con el cliente server. Si la consulta falla, la sección de leaderboard muestra un mensaje de error en vez de romper la página.
- `app/salon-de-la-fama/page.tsx` (client component): el `useMemo` con `seededScores` se reemplaza por un `useEffect` que llama a `getLeaderboard(supabase, tab, 12)` con el cliente browser cada vez que cambia `tab`, con estado de carga.
- Documentar en `README.md` las tablas nuevas, cómo se siembran y la política de RLS. Actualizar la nota de `CLAUDE.md`/`AGENTS.md` si sigue diciendo que ninguna pantalla usa Supabase.

**Out of scope (para specs futuros):**

- Migrar el catálogo visual: Biblioteca, Detalle y Salón de la Fama siguen leyendo `GAMES` de `lib/data.ts` para título, descripción, portada, categoría, color y "plays". La tabla `games` queda creada y sembrada pero sin ninguna pantalla leyéndola todavía — se acepta la duplicación temporal entre `lib/data.ts` y la tabla `games`.
- Auth y la fila "tu mejor marca" en el Salón de la Fama. Sigue sin existir sesión; `scores.name` sigue siendo texto libre tecleado en el modal de fin de partida, igual que hoy.
- Cualquier validación de servidor sobre los inserts de `scores` (rango de score razonable, filtro de groserías, rate limiting, CAPTCHA). El insert anónimo queda tan abierto como lo estaba `localStorage` hoy — cualquiera puede escribir cualquier score desde la consola del navegador.
- Edición o borrado de puntuaciones (ni UI ni policy de `UPDATE`/`DELETE`).
- Paginación del leaderboard más allá de los `LIMIT` fijos (10 en Detalle, 12 en Salón de la Fama).
- Calcular `plays` (contador de partidas) de forma dinámica a partir de filas reales de `scores`. Sigue siendo el valor mock de `lib/data.ts`.
- Dual-write a `localStorage`: se reemplaza por completo, no se mantiene como respaldo.
- Sonido, i18n, modo claro.

---

## Modelo de datos

```sql
-- supabase/migrations/20261006000000_games_and_scores.sql

create table public.games (
  id text primary key,
  title text not null,
  short text not null,
  long text not null,
  cat text not null,
  cover text not null,
  color text not null,
  best integer not null,
  plays text not null
);

create table public.scores (
  id bigint generated always as identity primary key,
  game_id text not null references public.games(id),
  name text not null,
  score integer not null,
  created_at timestamptz not null default now()
);

create index scores_game_id_score_idx on public.scores (game_id, score desc);

alter table public.games enable row level security;
alter table public.scores enable row level security;

create policy "games_select_all" on public.games
  for select to anon, authenticated using (true);

create policy "scores_select_all" on public.scores
  for select to anon, authenticated using (true);

create policy "scores_insert_anon" on public.scores
  for insert to anon, authenticated with check (true);

-- + INSERT con los 8 juegos de lib/data.ts (games)
-- + INSERT con 96 filas (12 por juego) generadas con la misma lógica de seededScores(gameId.length * 23 + 7, 12)
```

Contrato TypeScript en `lib/supabase/scores.ts`:

```ts
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "./database.types";

export interface LeaderboardRow {
  rank: number;
  name: string;
  score: number;
  date: string; // DD/MM/YYYY, derivado de created_at
}

export async function getLeaderboard(
  supabase: SupabaseClient<Database>,
  gameId: string,
  limit: number,
): Promise<LeaderboardRow[]>;

export async function getBestScore(
  supabase: SupabaseClient<Database>,
  gameId: string,
): Promise<number | null>;

export async function saveScore(
  supabase: SupabaseClient<Database>,
  gameId: string,
  name: string,
  score: number,
): Promise<{ ok: true } | { ok: false; error: string }>;
```

Convenciones:

- `getLeaderboard` ordena por `score desc` y asigna `rank` en memoria (1-indexado) a partir del orden devuelto; no se almacena `rank` en la tabla.
- `LeaderboardRow` reemplaza a `ScoreRow` como el tipo que consumen las pantallas. `ScoreRow`, `seededScores` y `PLAYERS` se quedan en `lib/data.ts` sin usarse desde pantallas (solo quedan como referencia de cómo se generaron los datos semilla); no se borran en este spec.
- `saveScore` nunca lanza: devuelve `{ ok: false, error }` en cualquier fallo (red, RLS, validación de Supabase) para que la UI pueda mostrar un error en vez de un `try/catch` silencioso como el de `localStorage`.
- Los clientes de Supabase se siguen creando solo vía `@/lib/supabase/server` o `@/lib/supabase/client` (SPEC 04); `scores.ts` nunca llama a `createClient()` él mismo, lo recibe como parámetro.

---

## Plan de implementación

1. Escribir un script one-off (fuera de `lib/`, en el scratchpad de la sesión) que reutilice la lógica de `seededScores` para generar de forma determinista las 96 filas de `scores` (12 por juego, semilla `gameId.length * 23 + 7`) y los 8 `INSERT` de `games` a partir de `GAMES`. Pegar el resultado como SQL literal en `supabase/migrations/20261006000000_games_and_scores.sql` junto con las tablas, el índice y las policies de RLS. Aplicar con `apply_migration`. Verificación: `list_migrations` la muestra; `execute_sql` con `select count(*) from games` devuelve 8 y `select count(*) from scores` devuelve 96.
2. Regenerar `lib/supabase/database.types.ts` con `generate_typescript_types`. Verificación: el archivo incluye `games` y `scores` en `Tables`.
3. Crear `lib/supabase/scores.ts` con `getLeaderboard`, `getBestScore` y `saveScore` tipados con `Database`. Verificación: `npm run build` pasa sin errores de tipos.
4. Actualizar `app/juegos/[id]/jugar/page.tsx`: `saveScore` pasa a ser async, usa el cliente browser (`@/lib/supabase/client`) y el helper nuevo; en error, muestra un mensaje en el modal (p. ej. "ERROR AL GUARDAR, INTENTA DE NUEVO") en vez del toast de éxito, y deja el botón disponible para reintentar. Quitar el acceso a `localStorage["av_scores"]`. Verificación manual (Playwright, captura en `.playwright-screenshots/`): jugar un juego cualquiera (demo y Rocas), guardar puntuación, confirmar el toast de éxito y verificar con `execute_sql` que aparece la fila nueva en `scores` con el `name`/`score` correctos.
5. Actualizar `app/juegos/[id]/page.tsx`: reemplazar `seededScores(id.length * 17 + 3, 10)` por `getLeaderboard(supabase, id, 10)` (cliente server) y `game.best` por `getBestScore(supabase, id)` en el stat-strip, con manejo de error que no rompe el resto de la página. Verificación manual: abrir `/juegos/rocas`, confirmar 10 filas reales (coinciden con las sembradas) y el stat "mejor global" igual al máximo real.
6. Actualizar `app/salon-de-la-fama/page.tsx`: reemplazar el `useMemo` con `seededScores` por un `useEffect` que llama `getLeaderboard(supabase, tab, 12)` con el cliente browser al cambiar `tab`, con un estado de carga simple (p. ej. ocultar podio/tabla mientras carga). Verificación manual: cambiar de tab para varios juegos, confirmar que el podio y la tabla de 12 filas coinciden con lo sembrado, y que una puntuación guardada en el paso 4 aparece si es top-12 de su juego.
7. Documentar en `README.md` (tablas `games`/`scores`, política de RLS, cómo se generaron los datos semilla) y actualizar `CLAUDE.md`/`AGENTS.md` si todavía dicen que ninguna pantalla usa Supabase. Verificación: `npm run build` y `npm run lint` pasan.

---

## Criterios de aceptación

- [ ] `supabase/migrations/20261006000000_games_and_scores.sql` existe en el repo y aparece en `list_migrations` del proyecto remoto.
- [ ] `select count(*) from games` devuelve 8 y los valores coinciden con `GAMES` de `lib/data.ts`.
- [ ] `select count(*) from scores` devuelve al menos 96 filas (las sembradas) distribuidas en 12 por juego antes de cualquier partida nueva.
- [ ] RLS está habilitada en `games` y `scores`; `anon` puede hacer `SELECT` en ambas e `INSERT` solo en `scores` (no `UPDATE`/`DELETE` en ninguna).
- [ ] `lib/supabase/database.types.ts` incluye `games` y `scores` en `Tables`.
- [ ] `lib/supabase/scores.ts` exporta `getLeaderboard`, `getBestScore` y `saveScore` tipados con `Database`.
- [ ] En el Reproductor, guardar puntuación en cualquiera de los 8 juegos agrega una fila real a `scores` (verificable con `execute_sql`) y ya no escribe en `localStorage["av_scores"]`.
- [ ] Si el insert de puntuación falla, el modal muestra un error en vez del toast de éxito, y el botón "GUARDAR PUNTUACIÓN" sigue disponible para reintentar.
- [ ] El Detalle de cualquier juego (`/juegos/[id]`) muestra un leaderboard de 10 filas y un stat "mejor global" que vienen de `scores`, no de `seededScores`/`game.best`.
- [ ] El Salón de la Fama muestra, por cada tab de juego, un podio y una tabla de 12 filas que vienen de `scores`, no de `seededScores`.
- [ ] Una puntuación guardada desde el Reproductor aparece en el Detalle y/o el Salón de la Fama del mismo juego si entra en el top correspondiente (10 o 12).
- [ ] Biblioteca, Detalle y Salón de la Fama siguen mostrando título, descripción, portada, categoría y "plays" desde `lib/data.ts` sin cambios visuales en esos campos.
- [ ] `npm run build` y `npm run lint` pasan sin errores.

---

## Decisiones

- **Sí:** un solo spec combinando tabla de catálogo (`games`) y leaderboard real (`scores`), en vez de dos specs separados. Decisión explícita del usuario pese a tocar varias pantallas; se documenta aquí en vez de dividir.
- **Sí:** crear y sembrar `games` pero sin conectar ninguna pantalla a ella todavía. Mismo patrón que SPEC 04: infraestructura verificada antes de migrar UI. Queda duplicación temporal aceptada entre `lib/data.ts` y la tabla `games`.
- **Sí:** el leaderboard real aplica a los 8 juegos, no solo a Rocas. El Reproductor ya centraliza el guardado de puntuación para todos los juegos (demo o real) desde SPEC 01; no hay motivo para bifurcar ese flujo por juego.
- **No:** validación de servidor, rate limiting o moderación sobre los inserts de `scores`. El insert anónimo queda tan abierto como estaba `localStorage` — mismo nivel de "confianza" que ya existía, no se introduce una regresión de seguridad, solo se mueve el dato a un lugar visible por todos.
- **Sí:** reemplazar `localStorage["av_scores"]` por completo en vez de dual-write. Una sola fuente de verdad es más simple y es la que necesitan Detalle/Salón para mostrar datos reales; mantener el dual-write solo agregaría una escritura muerta que nadie lee.
- **Sí:** sembrar `scores` con 96 filas (12 por juego) vía migración, generadas una sola vez con la misma lógica de `seededScores(gameId.length * 23 + 7, 12)` que hoy usa el Salón de la Fama. Unifica las dos semillas distintas que hoy coexisten (Detalle usaba `id.length * 17 + 3, 10`; Salón usaba `tab.length * 23 + 7, 12`) en una sola tabla real; Detalle simplemente lee el top 10 de esas mismas 12 filas por juego.
- **Sí:** también conectar el leaderboard lateral y el "mejor global" del Detalle a `scores`, no solo el Salón de la Fama. Evita tener dos "verdades" de puntuación real en pantallas distintas de la misma app.
- **Sí:** `getLeaderboard`/`getBestScore`/`saveScore` reciben el cliente de Supabase como parámetro en vez de crearlo ellos mismos, para poder llamarse tanto desde el Detalle (server component) como desde el Reproductor y el Salón de la Fama (client components), reutilizando los clientes ya definidos en SPEC 04.
- **Sí:** en error de lectura (Detalle/Salón) o escritura (Reproductor), mostrar un mensaje claro en vez de fallar en silencio o fingir éxito. Sigue la misma filosofía de SPEC 04 ("no fallback silencioso a mock").
- **No:** borrar `ScoreRow`, `seededScores` ni `PLAYERS` de `lib/data.ts`. Quedan sin uso desde pantallas pero documentan cómo se generaron los datos semilla; borrarlos no aporta nada en este spec y complica reproducir la semilla si hace falta regenerarla.
- **No:** calcular `plays` dinámicamente desde `scores`. Se mantiene como valor mock de `lib/data.ts`; recalcularlo pertenece al spec que migre el catálogo visual completo.

---

## Riesgos

| Riesgo                                                                                                                                                                                                    | Mitigación                                                                                                                                                                                       |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| El insert anónimo a `scores` queda abierto sin ninguna validación: cualquiera puede inflar el leaderboard desde la consola del navegador con scores absurdos.                                             | Aceptado explícitamente como decisión (mismo nivel de confianza que `localStorage` hoy). Si se vuelve un problema real, un spec futuro agrega validación de servidor o Auth.                     |
| Las 96 filas semilla y las filas reales conviven en la misma tabla sin ninguna marca que las distinga; no hay forma de saber desde la UI cuáles son "reales".                                             | Aceptado: el objetivo de la semilla es solo evitar un leaderboard vacío en el arranque, igual que `seededScores` ya hacía antes de este spec. Diferenciarlas es un spec futuro si hace falta.    |
| Divergencia entre `games` (tabla, sembrada una vez) y `lib/data.ts` (`GAMES`, sigue siendo la fuente real para las pantallas): si alguien edita uno y no el otro, quedan desincronizados.                 | Aceptado como riesgo temporal del scope elegido; se resuelve cuando un spec futuro migre las pantallas a leer `games` y se pueda borrar `GAMES` o dejarlo solo como seed.                        |
| Si Supabase no responde, el Detalle (server component) podría romper toda la página si la consulta de leaderboard no se maneja con cuidado.                                                               | `getLeaderboard`/`getBestScore` nunca lanzan hacia la página: el `page.tsx` las envuelve y muestra un mensaje de error acotado a la sección de leaderboard, sin afectar portada/descripción/CTA. |
| El Salón de la Fama asume hoy que siempre hay al menos 3 filas para el podio (`rows[0]`, `rows[1]`, `rows[2]`). Si por algún motivo `scores` tuviera menos de 3 filas para un juego, el componente rompe. | No debería ocurrir: cada juego queda sembrado con 12 filas desde la migración y nunca se borran filas. No se agrega manejo de "menos de 3 filas" en este spec porque el piso de 12 lo garantiza. |

---

## Lo que **no** está en este spec

- Migrar Biblioteca/Detalle/Salón a leer el catálogo (`games`) en vez de `lib/data.ts`.
- Auth, sesiones, o la fila "tu mejor marca" en el Salón de la Fama.
- Validación de servidor, rate limiting, CAPTCHA o moderación sobre los inserts de `scores`.
- Edición o borrado de puntuaciones, y cualquier policy de `UPDATE`/`DELETE`.
- Paginación del leaderboard más allá de los límites fijos (10/12).
- Cálculo dinámico de `plays`.
- Sonido, i18n, modo claro.

Cada uno de estos, si se implementa, va en su propio spec.
