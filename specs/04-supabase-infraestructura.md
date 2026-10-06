# SPEC 04 — Infraestructura de Supabase en Arcade Vault

> **Estado:** Implementado
> **Depende de:** SPEC 01
> **Fecha:** 2026-10-05
> **Objetivo:** Conectar la app de Next.js al proyecto de Supabase (`tofsihotqiekjknybuso`) con clientes tipados para server y browser, migraciones SQL versionadas y un endpoint de health, sin cambiar ninguna pantalla.

---

## Por qué existe este spec

Hasta ahora todo es mock (`lib/data.ts`). `.mcp.json` ya apunta al proyecto de Supabase, pero la app no tiene ni paquetes, ni clientes, ni variables de entorno. Antes de mover datos reales (catálogo, puntuaciones, auth) hace falta una base común: cómo se crean los clientes, dónde viven los tipos, cómo se versiona el esquema y cómo se comprueba que la conexión funciona. Este spec fija esas decisiones una sola vez para que los specs siguientes solo añadan tablas y consultas.

Estado actual del proyecto remoto (comprobado con el MCP de Supabase): el esquema `public` está vacío y la URL es `https://tofsihotqiekjknybuso.supabase.co`. `.env.local` solo contiene `SUPABASE_DB_PASSWORD`.

---

## Scope

**In:**

- Instalar `@supabase/supabase-js` y `@supabase/ssr` como dependencias.
- Variables de entorno `NEXT_PUBLIC_SUPABASE_URL` y `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (clave `sb_publishable_…`), añadidas a `.env.local` con los valores reales del proyecto.
- `lib/supabase/env.ts`: lee y valida las dos variables. Si falta alguna, lanza un `Error` con un mensaje que nombra la variable que falta.
- `lib/supabase/server.ts`: `createClient()` async para Server Components y Route Handlers, con `createServerClient` de `@supabase/ssr` y `await cookies()` de `next/headers`, tipado con `Database`.
- `lib/supabase/client.ts`: `createClient()` para Client Components, con `createBrowserClient` de `@supabase/ssr`, tipado con `Database`.
- `supabase/migrations/`: carpeta de migraciones SQL versionadas. Primera migración `supabase/migrations/20261005000000_health_check.sql`, que crea la función `public.health_check()` (devuelve `true`) con `execute` concedido a `anon` y `authenticated`. Se aplica al proyecto remoto con `apply_migration` del MCP de Supabase usando el mismo nombre.
- `lib/supabase/database.types.ts`: tipos generados con `generate_typescript_types` del MCP tras aplicar la migración. No se editan a mano.
- `app/api/health/supabase/route.ts`: `GET` que llama a `supabase.rpc("health_check")` con el cliente server. Responde `200 { ok: true }` si la llamada devuelve `true`. Responde `503 { ok: false, error: string }` si falla la llamada o faltan las variables de entorno.
- `.env.example` versionado con las dos variables públicas y sin valores reales, más la excepción `!.env.example` en `.gitignore`.
- Documentación: sección "Supabase" en `README.md` (variables, migraciones, regenerar tipos, health check). Actualizar la nota de `CLAUDE.md` que dice que "nothing in the app uses Supabase yet".

**Out of scope (para specs futuros):**

- Cualquier tabla de dominio (`games`, `scores`, `profiles`…) y migrar el catálogo de `lib/data.ts` a Supabase.
- Que alguna pantalla (Home, Biblioteca, Detalle, Reproductor, Salón, Acerca de) lea o escriba en Supabase.
- Auth (login, registro, sesiones) y el `proxy.ts` de Next 16 que refresca la sesión. Van juntos en el spec de Auth.
- Persistencia de puntuaciones o del formulario de contacto.
- Supabase CLI y stack local con Docker.
- Clave `service_role` / secret key y cualquier cliente con privilegios de administrador.
- Storage, Realtime y Edge Functions.

---

## Modelo de datos

No se introduce ninguna tabla. La única pieza de esquema es una función de health:

```sql
-- supabase/migrations/20261005000000_health_check.sql
create or replace function public.health_check()
returns boolean
language sql
stable
security invoker
set search_path = ''
as $$ select true $$;

grant execute on function public.health_check() to anon, authenticated;
```

Variables de entorno (`.env.example`):

```bash
NEXT_PUBLIC_SUPABASE_URL=https://<project-ref>.supabase.co
NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Respuesta del endpoint de health:

```ts
type HealthResponse = { ok: true } | { ok: false; error: string };
```

Convenciones:

- Los clientes se importan siempre desde `@/lib/supabase/server` o `@/lib/supabase/client`. Nadie llama a `createServerClient` o `createBrowserClient` directamente fuera de esos archivos.
- El nombre del archivo de migración y el `name` pasado a `apply_migration` coinciden (`20261005000000_health_check`).
- Tras cada migración se regenera `lib/supabase/database.types.ts`.

---

## Plan de implementación

1. Instalar `@supabase/supabase-js` y `@supabase/ssr`. Antes de escribir código, leer en `node_modules/next/dist/docs/` lo relativo a `cookies()` y Route Handlers (AGENTS.md). Verificación: `npm run build` pasa sin cambios en la app.
2. Crear `.env.example`, añadir `!.env.example` a `.gitignore` y añadir a `.env.local` las dos variables con los valores de `get_project_url` y `get_publishable_keys` del MCP. Verificación: `git status` muestra `.env.example` como nuevo y `.env.local` sigue ignorado.
3. Crear `supabase/migrations/20261005000000_health_check.sql` y aplicarla con `apply_migration`. Verificación: `list_migrations` muestra la migración y `execute_sql` con `select public.health_check();` devuelve `true`.
4. Generar `lib/supabase/database.types.ts` con `generate_typescript_types`. Verificación: el archivo exporta `Database` e incluye `health_check` en `Functions`.
5. Crear `lib/supabase/env.ts`, `lib/supabase/server.ts` y `lib/supabase/client.ts` tipados con `Database`. Verificación: `npm run build` pasa.
6. Crear `app/api/health/supabase/route.ts`. Verificación: `curl localhost:3000/api/health/supabase` devuelve `200 {"ok":true}` con `npm run dev`.
7. Documentar en `README.md` y actualizar `CLAUDE.md`. Verificación: `npm run build` y `npm run lint` pasan.

---

## Criterios de aceptación

- [x] `package.json` lista `@supabase/supabase-js` y `@supabase/ssr` en `dependencies`.
- [x] `supabase/migrations/20261005000000_health_check.sql` existe en el repo y aparece en `list_migrations` del proyecto remoto.
- [x] `select public.health_check();` devuelve `true` en el proyecto remoto.
- [x] `lib/supabase/database.types.ts` existe, fue generado por el MCP y contiene `health_check`.
- [x] `lib/supabase/server.ts` y `lib/supabase/client.ts` exportan `createClient()` tipado con `Database`.
- [x] Con `.env.local` completo, `GET /api/health/supabase` responde `200` con `{"ok":true}`.
- [x] Sin `NEXT_PUBLIC_SUPABASE_URL` o `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`, `GET /api/health/supabase` responde `503` con `ok: false` y un `error` que nombra la variable que falta.
- [x] `.env.example` está versionado con las 2 variables y sin valores reales. `.env.local` sigue fuera de git.
- [x] Ningún archivo versionado contiene la publishable key real, `SUPABASE_DB_PASSWORD` ni ninguna secret key.
- [x] No existe `proxy.ts` ni `middleware.ts` en el repo.
- [x] `/`, `/biblioteca`, `/juegos/[id]`, `/juegos/[id]/jugar`, `/salon-de-la-fama` y `/acerca-de` se ven y funcionan igual que antes de este spec.
- [x] `README.md` tiene una sección "Supabase" y `CLAUDE.md` ya no dice que la app no usa Supabase.
- [x] `npm run build` y `npm run lint` pasan sin errores.

---

## Decisiones

- **Sí:** solo infraestructura, sin tablas de dominio ni pantallas conectadas. Así el spec es pequeño y la base queda verificada antes de mover datos reales.
- **No:** migrar ya el catálogo de juegos o los leaderboards. Cada uno va en su propio spec sobre esta base.
- **Sí:** `@supabase/ssr` con un cliente server y otro browser. Es el patrón oficial para Next.js App Router y deja el terreno listo para Auth con cookies.
- **No:** `proxy.ts` para refrescar la sesión. Solo sirve con usuarios autenticados y se añade en el spec de Auth.
- **Sí:** publishable key (`NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY`). Es el formato actual de claves de Supabase.
- **No:** anon key JWT (legacy).
- **Sí:** migraciones SQL versionadas en `supabase/migrations/`, aplicadas con el MCP (`apply_migration`). Son reproducibles y revisables en el PR sin depender de Docker.
- **No:** cambios de esquema solo por MCP sin archivo, ni Supabase CLI con stack local.
- **Sí:** tipos generados (`lib/supabase/database.types.ts`). Evitan desincronizar a mano el esquema y el código.
- **Sí:** si faltan las variables o Supabase no responde, se muestra un error claro (lanzar `Error` / responder `503`). No se oculta con datos mock.
- **No:** fallback silencioso a `lib/data.ts`. Ocultaría errores de configuración.
- **Sí:** endpoint `GET /api/health/supabase` como verificación. Es comprobable con curl y sirve también en producción.
- **Sí:** función `public.health_check()` como objetivo del health check. Con el esquema vacío no hay ninguna tabla que consultar. Una RPC trivial prueba URL, clave y permisos de `anon` de punta a punta, y además estrena el flujo migración → tipos.
- **Sí:** `.env.example` versionado con excepción en `.gitignore`. Documenta las variables sin exponer valores.

---

## Riesgos

| Riesgo                                                                                                                         | Mitigación                                                                                                                                   |
| ------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| Next 16 cambió APIs (`cookies()` async, `middleware` → `proxy`) y los ejemplos de Supabase pueden asumir versiones anteriores. | Leer `node_modules/next/dist/docs/` antes de escribir los clientes (paso 1). Usar `await cookies()`.                                         |
| En un Server Component, `cookies().set` lanza un error. El cliente server de `@supabase/ssr` intenta escribir cookies.         | Envolver `setAll` en `try/catch`, como en el patrón oficial. Sin Auth no se escriben cookies de sesión.                                      |
| Filtrar la publishable key real o `SUPABASE_DB_PASSWORD` en el repo.                                                           | Valores solo en `.env.local` (ignorado). `.env.example` con placeholders. Revisar el diff antes del PR.                                      |
| Desfase entre el archivo de migración y lo aplicado en remoto.                                                                 | Mismo nombre en archivo y `apply_migration`. Comprobar con `list_migrations`.                                                                |
| El build falla si las variables no existen en el entorno de build (p.ej. CI o Vercel).                                         | Las variables se leen en runtime dentro de `createClient()`, no al importar el módulo. El endpoint responde `503` en vez de romper el build. |

---

## Lo que **no** está en este spec

- Tablas de dominio (`games`, `scores`, `profiles`) y migración de `lib/data.ts`.
- Pantallas que lean o escriban en Supabase.
- Auth, sesiones y `proxy.ts`.
- Persistencia de puntuaciones o del formulario de contacto.
- Supabase CLI / stack local, `service_role`, Storage, Realtime y Edge Functions.

Cada uno de estos, si se implementa, va en su propio spec.
