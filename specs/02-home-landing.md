# SPEC 02 — Home (landing) de Arcade Vault

> **Estado:** Implementado
> **Depende de:** SPEC 01
> **Fecha:** 2026-09-28
> **Objetivo:** Portar a Next.js App Router la pantalla Home (landing) definida en `references/resources/resources/templates/home-about/home-about/home.jsx`, moviendo la Biblioteca actual de `/` a `/biblioteca` y actualizando el Nav para reflejar la nueva jerarquía de rutas.

---

## Por qué existe este spec

SPEC 01 portó Biblioteca a la ruta raíz (`/`) porque en ese momento no existía la pantalla Home. El template de referencia (`home-about`) trae un `home.jsx` que es una landing real (hero, propuesta de valor, preview de juegos, stats, actividad en vivo, pricing, CTA final) pensada para vivir en `/`, con Biblioteca como una ruta propia. Este spec fija cómo se reordenan las rutas y qué contenido del landing se porta antes de tocar código, para no improvisar decisiones de routing ni de datos mock durante la implementación.

La carpeta de referencia también trae `about.jsx` (pantalla "Acerca de" + formulario de contacto), que queda explícitamente fuera de este spec y se implementará en uno futuro.

---

## Scope

**In:**

- Pantalla **Home** (`home.jsx`) portada a la ruta `/`:
  - **Hero**: siluetas pixel flotantes decorativas (`FloatingSilhouettes`), eyebrow "▸ INSERTA UNA MONEDA", título en 3 líneas, subtítulo, dos CTAs (explorar juegos → `/biblioteca`, crear cuenta → destino inerte igual que "Iniciar Sesión" en SPEC 01) e indicador de scroll.
  - **Sección "¿Por qué Arcade Vault?"**: grid de 4 `feature-card` con icono pixel (`FeatureIcon`: GAMEPAD, FREE, TROPHY, ROCKET), color y texto tal cual el template.
  - **Sección "Juegos disponibles ahora"**: rail de 6 `MiniCard` (nuevo componente, distinto del `GameCard` con tilt de Biblioteca) generado a partir de `GAMES.slice(0, 6)` de `lib/data.ts`, cada una enlazando a `/juegos/[id]`, y botón "VER TODOS LOS JUEGOS →" a `/biblioteca`.
  - **Sección de stats**: 3 bloques (`12+ JUEGOS`, `MILES DE PARTIDAS`, `GLOBAL RANKING`) con los textos fijos del template.
  - **Sección "Actividad en viva"**: dos tarjetas — ticker de "últimas puntuaciones" y "top jugadores · hoy" — con los datos de ejemplo *hardcodeados tal cual el template* (mismos nombres, juegos y puntuaciones de `home.jsx`), sin generarlos desde `lib/data.ts`. El botón "VER SALÓN →" navega a `/salon-de-la-fama`.
  - **Sección de precios**: tarjeta única "JUGADOR VAULT" ($0/siempre) con la lista de beneficios y CTA "EMPEZAR GRATIS →" (destino inerte, igual que "Crear cuenta"), más el FAQ de 3 preguntas, todo con el copy del template.
  - **CTA final**: título, botón "INSERTAR MONEDA →" a `/biblioteca`, tagline.
  - Animación `reveal`-on-scroll (IntersectionObserver) igual que en Biblioteca/Detalle/Salón.
- **Mover** la pantalla Biblioteca actual (hoy en `app/page.tsx`) a `app/biblioteca/page.tsx` sin cambios de comportamiento (buscador, chips, grid con tilt, estado vacío).
- Actualizar todos los enlaces internos que hoy apuntan a `/` esperando la Biblioteca (`components/Nav.tsx`, `app/juegos/[id]/page.tsx`, `app/juegos/[id]/jugar/page.tsx`, `app/salon-de-la-fama/page.tsx`) para que apunten a `/biblioteca`, salvo el logo del Nav que debe apuntar a `/` (Home).
- Actualizar `components/Nav.tsx`: 3 links — "Inicio" (`/`), "Biblioteca" (`/biblioteca` y sus subrutas `/juegos/*`), "Salón de la Fama" (`/salon-de-la-fama`) — con resaltado de link activo según la ruta actual.
- Portar a `app/globals.css` las reglas del template necesarias para Home que todavía no existen (`.home-hero`, `.home-silos` y `.silo`, `.home-title`, `.home-sub`, `.home-ctas`, `.home-section`, `.feature-grid`/`.feature-card`/`.ft-*`, `.mini-rail`/`.mini-card`/`.mini-cover`/`.mini-meta`/`.mini-title`/`.mini-cat`, `.home-stats`/`.stat-block`/`.stat-n`/`.stat-u`/`.stat-s`, `.activity-grid`/`.activity-card`/`.ticker`/`.tick-row`/`.top-list`/`.top-row`, `.pricing-grid`/`.price-card`/`.pc-*`/`.pricing-faq`/`.faq-*`, `.home-final`/`.final-title`/`.final-cta`/`.final-tag`).
- Nuevos componentes: `components/MiniCard.tsx` (client) y las piezas de iconografía del Home (silhouettes decorativas y `FeatureIcon`) como componentes o funciones locales de `app/page.tsx`.

**Out of scope (para specs futuros):**

- Pantalla **Acerca de** (`about.jsx`) con su formulario de contacto simulado — spec propio, incluirá el 4º link "Acerca de" en el Nav.
- El botón "CREAR CUENTA" del hero y "EMPEZAR GRATIS →" de precios quedan inertes, igual que "Iniciar Sesión" — no navegan a ningún flujo de autenticación real ni simulado (eso es del spec de Auth, ya excluido en SPEC 01).
- Generar las secciones de "Actividad en vivo" a partir de datos reales o de `lib/data.ts`/`seededScores` — se mantienen como contenido mock estático igual al template.
- Cualquier lógica de juego real, persistencia de puntuaciones nuevas, sonido o i18n — igual que en SPEC 01.

---

## Modelo de datos

No se introduce ningún dato nuevo. La sección "Juegos disponibles ahora" reutiliza `GAMES` de `lib/data.ts` (ya definido en SPEC 01), tomando los primeros 6 elementos. Las secciones de stats, actividad en vivo y precios usan texto/arrays literales tomados directamente del template, sin tipar como modelo de datos reutilizable (son contenido de una sola pantalla).

---

## Plan de implementación

1. Mover el contenido actual de `app/page.tsx` a `app/biblioteca/page.tsx` sin modificarlo. Verificación: `npm run dev` sirve `/biblioteca` con el mismo comportamiento (buscador, chips, grid, tilt, estado vacío) que tenía `/` antes del cambio.
2. Actualizar `components/Nav.tsx`: reemplazar los 2 links actuales por 3 ("Inicio" → `/`, "Biblioteca" → `/biblioteca`, "Salón de la Fama" → `/salon-de-la-fama"), el logo apunta a `/`, y la lógica de link activo considera `/biblioteca` y `/juegos/*` como "Biblioteca" activa. Verificación: navegar a `/`, `/biblioteca`, `/juegos/[id]` y `/salon-de-la-fama` resalta el link correcto en desktop y en el menú mobile.
3. Actualizar los enlaces "volver"/"salir" que hoy apuntan a `/` en `app/juegos/[id]/page.tsx` y `app/juegos/[id]/jugar/page.tsx`, y el botón "VER TODOS" en `app/salon-de-la-fama/page.tsx`, para que apunten a `/biblioteca`. Verificación: cada botón navega a `/biblioteca`, no a la nueva Home.
4. Portar a `app/globals.css` las reglas CSS de Home listadas en el scope, copiándolas de `references/resources/resources/templates/home-about/home-about/styles.css`. Verificación: no hay clases de Home usadas en el JSX que falten en `globals.css` (revisión visual, sin errores de estilos rotos).
5. Crear `components/MiniCard.tsx` portando `MiniCard` de `home.jsx` (portada + título + categoría, click navega a `/juegos/[id]`). Verificación: se renderiza igual que en el template, sin lógica de tilt (esa es exclusiva de `GameCard`).
6. Crear `app/page.tsx` (nuevo Home) portando `home.jsx` completo: hero con siluetas decorativas, sección "por qué", rail de `MiniCard` con `GAMES.slice(0, 6)`, stats, actividad en vivo (datos hardcodeados), precios + FAQ, y CTA final. Usar el mismo hook de `reveal`-on-scroll que ya existe en Biblioteca/Detalle/Salón. Verificación: `npm run dev` sirve `/` con las 6 secciones visibles, el CTA "EXPLORAR JUEGOS" y "INSERTAR MONEDA" navegan a `/biblioteca`, y las 6 mini-cards navegan a `/juegos/[id]` correcto.
7. Revisión final de navegación cruzada: confirmar que ninguna ruta existente (`/juegos/[id]`, `/juegos/[id]/jugar`, `/salon-de-la-fama`) quedó con un enlace roto a `/` que debiera ser `/biblioteca`. Verificación: `npm run build` y `npm run lint` sin errores, y click-through manual de las 4 rutas.

---

## Criterios de aceptación

- [x] `npm run dev` sirve `/` con el landing Home (hero, por qué, preview de juegos, stats, actividad en vivo, precios, CTA final) y sin errores de consola.
- [x] `npm run dev` sirve `/biblioteca` con el mismo comportamiento de búsqueda/filtro/tilt/estado vacío que tenía `/` antes de este spec.
- [x] `npm run build` y `npm run lint` pasan sin errores.
- [x] El Nav muestra 3 links (Inicio, Biblioteca, Salón de la Fama) y resalta el activo correctamente en `/`, `/biblioteca`, `/juegos/[id]` y `/salon-de-la-fama`.
- [x] El logo del Nav navega a `/` (Home) desde cualquier pantalla.
- [x] En el Home, el botón "▶ EXPLORAR JUEGOS" del hero y "INSERTAR MONEDA →" del CTA final navegan a `/biblioteca`.
- [x] En el Home, "✦ CREAR CUENTA" y "EMPEZAR GRATIS →" no navegan a ninguna parte (botones inertes).
- [x] La sección "Juegos disponibles ahora" muestra 6 `MiniCard` generadas desde `GAMES` y cada una navega a `/juegos/<id>` correcto al hacer clic.
- [x] El botón "VER TODOS LOS JUEGOS →" del Home navega a `/biblioteca`.
- [x] El botón "VER SALÓN →" de la sección de actividad navega a `/salon-de-la-fama`.
- [x] Las secciones de stats, actividad en vivo y precios/FAQ muestran el contenido fijo del template, sin datos generados dinámicamente.
- [x] Ningún botón "volver"/"salir"/"ver todos" en Detalle, Reproductor o Salón de la Fama navega a `/` esperando ver la Biblioteca — todos apuntan a `/biblioteca`.
- [x] Las animaciones `reveal`-on-scroll de las secciones del Home se activan al hacer scroll, igual que en las demás pantallas.

---

## Decisiones

- **Sí:** mover la Biblioteca de `/` a `/biblioteca` en vez de anidar el Home en otra ruta. El template asume `/` = landing, y es la convención más estándar para un producto con página de inicio propia.
- **Sí:** dejar fuera de este spec la pantalla Acerca de (`about.jsx`), aunque viene en la misma carpeta de referencia (`home-about`). Tiene su propio formulario y lógica de validación/simulación de envío que merece su propio ciclo de definición.
- **Sí:** omitir el link "Acerca de" del Nav en este spec en vez de agregarlo inerte. Evita un elemento de navegación visible sin destino ni siquiera decorativo; se agrega junto con su spec.
- **Sí:** mantener el contenido de "Actividad en vivo" como mock estático copiado tal cual del template, en vez de generarlo con `seededScores`/`PLAYERS` de `lib/data.ts`. Es contenido puramente decorativo de la landing (no es un leaderboard real como el de Detalle o Salón), y replicar el template evita inventar una fuente de verdad para datos que no se van a usar en ninguna otra pantalla.
- **Sí:** crear `MiniCard` como componente nuevo en vez de reutilizar `GameCard`. El template los define como componentes visualmente distintos (`MiniCard` no tiene el efecto tilt ni el mismo layout que `GameCard`), y forzar una sola implementación para dos diseños distintos complicaría ambos.
- **Sí:** los CTAs "Crear cuenta" y "Empezar gratis" quedan inertes, siguiendo la misma decisión de SPEC 01 para "Iniciar Sesión" — no hay Auth implementado todavía.
- **No:** redirigir automáticamente `/` a `/biblioteca` o viceversa. Son dos pantallas distintas y permanentes; no es una migración temporal.

---

## Riesgos

| Riesgo | Mitigación |
| --- | --- |
| Mover `app/page.tsx` a `app/biblioteca/page.tsx` puede dejar imports o rutas relativas rotas si el archivo asume que vive en la raíz. | El archivo actual solo usa imports absolutos (`@/components/...`, `@/lib/data`), por lo que mover el archivo no debería requerir tocar sus imports; verificar con `npm run build` tras el movimiento. |
| Las 8 secciones del Home portadas tal cual (~200 líneas de JSX) pueden chocar visualmente con clases ya existentes en `globals.css` de Biblioteca/Detalle (p.ej. `.stat-strip` ya existe con otro propósito). | Revisar que los nombres de clase portados de `home.jsx` (`.home-*`, `.mini-*`, `.feature-*`, `.stat-block`, `.activity-*`, `.pricing-*`, `.pc-*`, `.faq-*`, `.final-*`) no colisionen con los ya usados por Detalle/Biblioteca antes de pegarlos en `globals.css`; en este repaso no se detectó colisión de nombres, solo de prefijo similar (`.stat-strip` vs `.stat-block`, que son distintos). |
| Enlaces internos que hoy apuntan a `/` esperando Biblioteca quedan silenciosamente rotos (llevan a Home) si se olvida alguno. | Grep de `href="/"` y `router.push("/")` en todo `app/` y `components/` antes de cerrar el spec (ya hecho en la fase de definición: se identificaron 4 ocurrencias a corregir) y click-through manual de las 4 rutas existentes. |

---

## Lo que **no** está en este spec

- Pantalla Acerca de (`about.jsx`) y su formulario de contacto simulado.
- El 4º link "Acerca de" en el Nav.
- Cualquier destino real para "Crear cuenta" / "Empezar gratis" (Auth).
- Datos reales o derivados de `lib/data.ts` para la sección "Actividad en vivo" del Home.
- Lógica de juego, persistencia nueva, sonido o i18n (ya excluidos desde SPEC 01).

Cada uno de estos, si se implementa, va en su propio spec.
