## Arcade Vault

Es una plataforma para jugar online y competir por la mayor cantidad de puntos.

Estado actual: el catálogo (Biblioteca, Detalle, Salón de la Fama) sigue mostrando título, portada, categoría y descripción desde datos mock (`lib/data.ts`). De los 8 juegos, **Rocas** (clon de Asteroids, `lib/games/asteroids.ts`) es jugable de verdad; el resto simula un puntaje con un timer en el Reproductor. En ambos casos la puntuación final se guarda de verdad en Supabase (tabla `scores`), y el leaderboard de Detalle y el Salón de la Fama leen esas mismas filas reales. Login y formulario de contacto siguen inertes.

## Usa Spec Driven Design

Basado en /spec y /spec-impl

Siguiendo las buenas practicas recomendadas aquí:
https://github.com/Klerith/fernando-skills

## Skills usadas

```bash
npx skills@latest add Klerith/fernando-skills
```
## Commands

- `npm run dev` — start the dev server (this is also what regenerates AGENTS.md, see above)
- `npm run build` — production build
- `npm run start` — run the production build
- `npm run lint` — lint with ESLint (flat config in `eslint.config.mjs`, extends `eslint-config-next`'s core-web-vitals and typescript configs)

There is no test runner configured in this project yet.

## Supabase

La app se conecta al proyecto de Supabase configurado en `.mcp.json` (SPEC 04).

### Variables de entorno

Copia `.env.example` a `.env.local` y rellena:

- `NEXT_PUBLIC_SUPABASE_URL` — URL del proyecto (`https://<project-ref>.supabase.co`).
- `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` — publishable key (`sb_publishable_…`), no la anon key legacy.

Nunca subas `.env.local` ni claves secretas (`service_role` / secret key) al repo.

### Clientes

- `lib/supabase/server.ts` — `await createClient()` en Server Components y Route Handlers.
- `lib/supabase/client.ts` — `createClient()` en Client Components.

Ambos están tipados con `Database` y lanzan un error que nombra la variable si falta alguna.

### Migraciones

Los cambios de esquema viven en `supabase/migrations/<timestamp>_<nombre>.sql` y se aplican al proyecto remoto con la herramienta `apply_migration` del MCP de Supabase, usando el nombre del archivo (sin `.sql`) como `name`.

### Tipos

Tras cada migración, regenera `lib/supabase/database.types.ts` con la herramienta `generate_typescript_types` del MCP. No lo edites a mano.

### Health check

`GET /api/health/supabase` responde `200 {"ok":true}` si la conexión funciona, o `503 {"ok":false,"error":"…"}` si falta configuración o Supabase no responde:

```bash
curl localhost:3000/api/health/supabase
```

### Tablas de dominio (SPEC 06)

Migración: `supabase/migrations/20261006000000_games_and_scores.sql`.

- **`games`** — catálogo de los 8 juegos (`id`, `title`, `short`, `long`, `cat`, `cover`, `color`, `best`, `plays`), sembrado 1:1 desde `GAMES` en `lib/data.ts`. Ninguna pantalla la lee todavía: Biblioteca, Detalle y Salón de la Fama siguen usando `lib/data.ts` para portada/categoría/descripción. Existe para que un spec futuro migre el catálogo sin tener que crear la tabla primero.
- **`scores`** — leaderboard real (`id` identity, `game_id` → FK a `games`, `name`, `score`, `created_at`), con índice `(game_id, score desc)`. Sembrada con 96 filas (12 por juego), generadas una sola vez con la misma lógica de `seededScores(gameId.length * 23 + 7, 12)` que antes usaba el Salón de la Fama — unifica lo que eran dos semillas distintas (Detalle y Salón) en una sola fuente. Desde entonces, cada partida guardada en el Reproductor (los 8 juegos, no solo Rocas) agrega una fila real vía `saveScore()`.
- **RLS**: habilitada en ambas tablas. `SELECT` abierto a `anon`/`authenticated` en `games` y `scores`; `INSERT` abierto a `anon`/`authenticated` solo en `scores`, sin validación de servidor (mismo nivel de confianza que tenía el `localStorage` que reemplaza). No hay `UPDATE` ni `DELETE` para nadie en ninguna tabla.
- **Helpers** (`lib/supabase/scores.ts`): `getLeaderboard(supabase, gameId, limit)`, `getBestScore(supabase, gameId)`, `saveScore(supabase, gameId, name, score)`. Reciben el cliente de Supabase como parámetro (server o browser) en vez de crearlo ellos mismos. `saveScore` nunca lanza: devuelve `{ ok: false, error }` para que la UI muestre el error en vez de fallar en silencio.
