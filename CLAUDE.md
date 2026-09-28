# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

@AGENTS.md

## Project

Arcade Vault — a platform for playing games online and competing for the highest score (see README.md). This is currently a freshly bootstrapped `create-next-app` project (Next.js 16.3.6, App Router, React 19, TypeScript, Tailwind CSS v4) with no game logic implemented yet.

The project intends to follow Spec Driven Design via the `/spec` and `/spec-impl` skills from https://github.com/Klerith/fernando-skills (installed with `npx skills@latest add Klerith/fernando-skills`). If those skills aren't present in this environment, ask the user before inventing spec files.


## Skills
Usa siempre /frontend-design para diseñar interfaces de usuario en HTML.

## Testing / screenshots

All images produced while testing or verifying the app (Playwright MCP screenshots, diffs, reference comparisons, etc.) go in `/.playwright-screenshots` at the repo root — pass `filename: "playwright-screenshots/<name>.png"` to the Playwright MCP screenshot tool. That folder is gitignored; it's scratch verification output, not part of the app.

## Architecture notes

- App Router only, all routes live under `app/`. There is no `pages/` directory.
- Path alias `@/*` maps to the repo root (`tsconfig.json`).
- `app/layout.tsx` types its `children` prop via the generated `LayoutProps<"/">` helper (from `.next/types`) rather than a hand-written props type — follow this pattern for new layouts/pages (`PageProps<"/route">`, `LayoutProps<"/route">`) instead of writing ad-hoc prop interfaces.
- Styling is Tailwind CSS v4 via the `@tailwindcss/postcss` PostCSS plugin (`postcss.config.mjs`); there is no `tailwind.config.js` — v4 is configured through CSS (`app/globals.css`) and PostCSS, not a JS config file.
- Fonts are loaded with `next/font/google` (Geist / Geist Mono) and exposed as CSS variables on the `<html>` element.
