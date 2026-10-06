## Arcade Vault

Es una plataforma para jugar online y competir por la mayor cantidad de puntos.

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

La app se conecta al proyecto de Supabase configurado en `.mcp.json` (SPEC 04). Todavía no hay tablas de dominio: las pantallas siguen usando los datos mock de `lib/data.ts`.

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
