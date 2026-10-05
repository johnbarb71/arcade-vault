# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

## Project

Arcade Vault — a platform for playing games online and competing for the highest score (see README.md). Next.js 16.3.6 (App Router), React 19, TypeScript, Tailwind CSS v4. UI copy and route names are in Spanish.

Current state: a **visual MVP** ported from the HTML/JSX design templates. All data is static/mock (`lib/data.ts`), the game player simulates a score with a timer, the contact form and "Iniciar Sesión" are inert. No backend, auth, persistence or real game logic yet — those are deferred to future specs. (`.mcp.json` configures a Supabase MCP server, but nothing in the app uses Supabase yet.)

## Commands

- `npm run dev` — dev server (also regenerates `AGENTS.md`)
- `npm run build` — production build (also the main type-check, since there is no separate `tsc` script)
- `npm run lint` — ESLint flat config (`eslint.config.mjs`, extends `eslint-config-next` core-web-vitals + typescript)

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

- App Router only, all routes under `app/`: `/` (home landing), `/biblioteca` (game library with search + category filter), `/juegos/[id]` (game detail + leaderboard), `/juegos/[id]/jugar` (player), `/salon-de-la-fama` (hall of fame), `/acerca-de` (about + contact form).
- `lib/data.ts` is the single mock data source: `GAMES` (typed `Game`), `CATS`, `PLAYERS`, and `seededScores(seed, count)`, a deterministic pseudo-random leaderboard generator (deterministic so server/client renders match). Pages look up games with `GAMES.find(g => g.id === id)` and call `notFound()` when missing.
- Type page/layout props with the generated global helpers `PageProps<"/route">` / `LayoutProps<"/route">` (from `.next/types`), not hand-written interfaces. `params` is a Promise: `await params` in server components, `use(params)` in client components.
- Pages are client components (`"use client"`) only when they need state; the detail page is a server component.
- **Styling**: almost all styling is hand-written CSS in `app/globals.css` (~1300 lines, ported from the template's `styles.css`) using semantic class names (`av-nav`, `av-hero`, `av-detail`, `cover-bg cover-bricks`, `neon-cyan`, `flicker`, `fade-in`, `reveal`…) plus occasional inline `style` objects. Tailwind v4 is loaded (`@import "tailwindcss"`, configured via `@theme inline` in CSS — no `tailwind.config.js`) but utility classes are rarely used. When porting a screen, port the missing template CSS rules into `globals.css` rather than rewriting them as Tailwind utilities.
- Theme tokens are CSS variables on `:root` in `globals.css` (`--bg*`, `--ink*`, neon `--cyan/--magenta/--yellow/--green`, `--gold/--silver/--bronze`, `--line*`, `--pixel`, `--mono`). Game covers are pure CSS (`.cover-*` classes); `Game.color` maps to the neon palette.
- Fonts: `next/font/google` in `app/layout.tsx` loads Press Start 2P (`--font-pixel`), JetBrains Mono and Courier Prime, exposed as CSS variables and consumed through `--pixel` / `--mono`.
- `app/layout.tsx` renders the shared shell: background layer, `components/Nav.tsx` (client; active link derived from `usePathname()`, mobile menu), `<main className="av-main">`, and footer.
- Scroll-reveal animations: add the `reveal` class to elements and call `useReveal()` (`lib/useReveal.ts`) in the page; it adds `.in` via IntersectionObserver.
- `demos/` is scratch code, not part of the app.

## Skills

Usa siempre /frontend-design para diseñar interfaces de usuario en HTML.

## Testing / screenshots

All images produced while testing or verifying the app (Playwright MCP screenshots, diffs, reference comparisons, etc.) go in `/.playwright-screenshots` at the repo root — pass `filename: ".playwright-screenshots/<name>.png"` to the Playwright MCP screenshot tool. That folder is gitignored; it's scratch verification output, not part of the app.
