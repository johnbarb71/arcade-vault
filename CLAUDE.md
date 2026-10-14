# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

## Project

Arcade Vault — a platform for playing games online and competing for the highest score (see README.md). UI copy and route names are in Spanish.

Current state: the visual catalog (Biblioteca, Detalle, Salón de la Fama) is still ported from the HTML/JSX design templates and reads game metadata (title, cover, category, description, `plays`) from static mock data (`lib/data.ts`). On top of that, scoring is real: one game, Rocas (`lib/games/asteroids.ts`, canvas-based Asteroids clone), is fully playable, and the other 7 games in the Reproductor still simulate a score with a timer. Whichever way a score is produced, it's saved for real to Supabase via `saveScore` (SPEC 06) — there's no `localStorage` fallback left. The side leaderboard and "best score" stat on Detalle, and the podium/table on Salón de la Fama, read real rows from the `scores` table (SPEC 06) instead of the old `seededScores` PRNG. Auth is real (SPEC 07): `/auth` has working sign-up/sign-in against Supabase Auth (email/password and Google/GitHub OAuth), `proxy.ts` protects every route except Inicio and Acerca de, and the Nav reflects the live session. Security hardening (SPEC 08) closed the remaining advisor warnings and checklist items: `scores.user_id` links new rows to `auth.users`, the 3 literal Next.js security headers are applied to every route, and password policy/sign-up rate limiting are configured (manually) in the Supabase dashboard — "Leaked password protection" couldn't be enabled, since it needs the Supabase Pro plan this project doesn't have. The contact form is still inert. No user profiles, or real game logic for the other 7 games yet — those are deferred to future specs.

Supabase infrastructure (SPEC 04): typed clients in `lib/supabase/server.ts` (`await createClient()`) and `lib/supabase/client.ts`, generated types in `lib/supabase/database.types.ts` (regenerate with the Supabase MCP after each migration, never edit by hand), SQL migrations in `supabase/migrations/` applied with the MCP's `apply_migration`, and `GET /api/health/supabase` as a connection check. Env vars: `NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY` (see `.env.example`).

Domain tables (SPEC 06): `games` (catalog, seeded 1:1 from `lib/data.ts`'s `GAMES` — not read by any screen yet, kept only so a future spec can migrate the catalog without creating the table) and `scores` (real leaderboard, seeded with 96 rows — 12 per game — plus every score a player actually saves). `lib/supabase/scores.ts` exports `getLeaderboard`, `getBestScore` and `saveScore`, each taking a `SupabaseClient<Database>` as a parameter (server or browser client, caller's choice) and never throwing from `saveScore` — callers get `{ ok: false, error }` and show it in the UI instead of failing silently. `ScoreRow`, `seededScores` and `PLAYERS` remain in `lib/data.ts` unused by screens, kept only as a record of how the seed data was generated. Since SPEC 07, RLS on both tables requires `authenticated` for `SELECT`/`INSERT` (the table-level `GRANT` to `anon` was revoked too — RLS alone only filters rows, it doesn't make the query fail). Since SPEC 08, `scores` also has a nullable `user_id uuid` column (FK to `auth.users(id)`, `default auth.uid()`) and the `INSERT` policy is `scores_insert_own` (`with check (auth.uid() = user_id)`) instead of SPEC 07's `scores_insert_authenticated` (`WITH CHECK (true)`); the client never sends `user_id`, so it can't be spoofed. The 96 seed rows keep `user_id = null` permanently — no screen reads or displays `user_id` yet.

Auth (SPEC 07): `app/auth/page.tsx` (tabs for sign-in/sign-up) and `app/auth/callback/route.ts` (OAuth code exchange) are the only entry points — there's no guest mode. `proxy.ts` at the project root refreshes the session on every request via `@supabase/ssr` and redirects to `/auth` for any route other than `/`, `/acerca-de`, `/auth`, `/auth/callback`, `/api/health/*`, or Next's internal assets. `components/Nav.tsx` reads the session client-side and subscribes to `onAuthStateChange`. `username` lives in `user_metadata` (no `profiles` table, no uniqueness) and is used to prefill the score-save modal's name field in the Reproductor. See `README.md` for the list of public/protected routes and the manual OAuth credential setup.

Security hardening (SPEC 08): `next.config.ts` exports a `headers()` function applying exactly 3 literal headers (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`, `Referrer-Policy: strict-origin-when-cross-origin`) to every route via `/(.*)`  — no `Strict-Transport-Security`, `Permissions-Policy` or CSP yet, deferred to avoid breaking Google Fonts/OAuth redirects without mapping every external source first. `public.rls_auto_enable()` (a platform-managed `SECURITY DEFINER` event-trigger function, not one of our migrations) had `EXECUTE` revoked from `anon`/`authenticated`/`public`. Password minimum length (8, plus a dashboard-added character-complexity requirement), and the sign-up rate limit (confirmed at 30/hour, Supabase's default) are configured manually in the Supabase dashboard, same pattern as SPEC 07's OAuth credentials — see `README.md` for the full list and the one checklist item left unmet ("Leaked password protection", Pro-plan-only).

## Commands

`npm run build` doubles as the type-check (no separate `tsc` script).

There is no test runner. Verification is done visually with the Playwright MCP (see below).

A `PostToolUse` hook on `Write` (`.claude/hooks/format-on-write.sh`) runs Prettier and `eslint --fix` on every file written; ESLint errors fail the hook (exit 2) and must be fixed.

## Spec Driven Design workflow

Work is driven by numbered specs in `specs/NN-slug.md`, using the `/spec` (design a spec) and `/spec-impl` (implement an approved spec) skills from Klerith/fernando-skills, installed in `.agents/skills/` and symlinked into `.claude/skills/`.

- Each spec has a header with **Estado** (state), **Depende de**, and explicit **In / Out of scope** sections. `/spec-impl` only proceeds on specs whose state means "Approved".
- `specs/.spec-config.yml` has `AutoCreateBranch: true`, so `/spec-impl` creates and switches to a `spec-NN-slug` branch automatically. Work is merged into `main` via PRs.
- Respect each spec's "Out of scope" list — don't implement deferred features (auth, persistence, real games, sound, i18n) unless a spec covers them.
- Read earlier specs before writing a new one; later specs build on decisions made in earlier ones.

## Design references

`references/resources/resources/templates/` holds the original design (standalone HTML + JSX prototypes: `app.jsx`, `biblioteca.jsx`, `detalle.jsx`, `reproductor.jsx`, `salon.jsx`, `nav.jsx`, `auth.jsx`, `styles.css`, and `home-about/` for Home and Acerca de). Screens are implemented by **porting** these templates to App Router, keeping their markup, class names and copy. `references/` is gitignored (local only); ignore the `__MACOSX` folders.

## Architecture notes

- Type page/layout props with the generated global helpers `PageProps<"/route">` / `LayoutProps<"/route">` (from `.next/types`), not hand-written interfaces. `params` is a Promise: `await params` in server components, `use(params)` in client components.
- Pages are client components (`"use client"`) only when they need state; the detail page is a server component.
- **Styling**: almost all styling is hand-written CSS in `app/globals.css` (~1300 lines, ported from the template's `styles.css`) using semantic class names (`av-nav`, `av-hero`, `av-detail`, `cover-bg cover-bricks`, `neon-cyan`, `flicker`, `fade-in`, `reveal`…) plus occasional inline `style` objects. Tailwind v4 is loaded (`@import "tailwindcss"`, configured via `@theme inline` in CSS — no `tailwind.config.js`) but utility classes are rarely used. When porting a screen, port the missing template CSS rules into `globals.css` rather than rewriting them as Tailwind utilities.
- Scroll-reveal animations: add the `reveal` class to elements and call `useReveal()` (`lib/useReveal.ts`) in the page; it adds `.in` via IntersectionObserver.
- `demos/` is scratch code, not part of the app.
- Real game logic lives in `lib/games/<id>.ts` as a framework-free factory (`createAsteroidsGame(canvas, onState)` → `{ setPaused, forceGameOver, destroy }`) driving a `<canvas>` with `requestAnimationFrame`; the Reproductor (`app/juegos/[id]/jugar/page.tsx`) branches on `game.id` to mount a real game's canvas vs. the generic timer-based score simulation used by the other 7 games. Adding a real game means dropping a new file in `lib/games/` and adding a branch there, not replacing the demo path wholesale.

## Skills

Usa siempre /frontend-design para diseñar interfaces de usuario en HTML.

## Agentes

`.claude/agents/security-auditor.md` audita RLS, advisors de Supabase, funciones `SECURITY DEFINER`, headers de `next.config.ts` y las rutas públicas de `proxy.ts` contra lo documentado en SPEC 07/08 y `references/Security/Checklist.md`. Invócalo (tool `Agent`, `subagent_type: "security-auditor"`) para pedir una auditoría de seguridad, o proactivamente después de tocar migraciones, políticas RLS, `proxy.ts` o `next.config.ts`. Solo reporta hallazgos — no aplica mitigaciones.

## Testing / screenshots

All images produced while testing or verifying the app (Playwright MCP screenshots, diffs, reference comparisons, etc.) go in `/.playwright-screenshots` at the repo root — pass `filename: ".playwright-screenshots/<name>.png"` to the Playwright MCP screenshot tool. That folder is gitignored; it's scratch verification output, not part of the app.


## Stack

- **Framework**: Next.js 16.3 (App Router) — breaking changes vs. older versions; see `AGENTS.md`.
- **UI**: React 19.2, TypeScript 5.
- **Styling**: hand-written CSS in `app/globals.css` + Tailwind CSS v4 (via `@tailwindcss/postcss`, configured with `@theme inline`).
- **Backend / DB**: Supabase (`@supabase/supabase-js` 2, `@supabase/ssr` 0.12) — SQL migrations in `supabase/migrations/`, managed through the Supabase MCP.
- **Tooling**: ESLint 9 (`eslint-config-next`), Prettier 3 (run automatically by the `PostToolUse` hook).
- **Verification**: Playwright MCP (visual checks; no test runner).
