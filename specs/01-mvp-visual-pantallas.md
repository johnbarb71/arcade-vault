# SPEC 01 — MVP visual de las pantallas de Arcade Vault

> **Estado:** Aprobado
> **Depende de:** —
> **Fecha:** 2026-09-28
> **Objetivo:** Portar a Next.js App Router, solo como interfaz visual y sin lógica de juego real, las pantallas Biblioteca, Detalle de juego, Reproductor y Salón de la Fama definidas en `references/resources/resources/templates/`.

---

## Por qué existe este spec

Los templates de referencia son una SPA de React con enrutamiento por hash (`app.jsx`) y un archivo de estilos propio (`styles.css`) que no usa Tailwind. Este spec fija cómo se traduce ese prototipo a la estructura real del proyecto (App Router, `lib/`, `components/`) antes de escribir código, para no improvisar decisiones de theming ni de rutas durante la implementación.

---

## Scope

**In:**

- Pantalla **Biblioteca** (`biblioteca.jsx`) en la ruta `/`: hero, buscador, chips de categoría, grid de `GameCard` con efecto tilt al pasar el mouse, estado vacío "NO HAY RESULTADOS".
- Pantalla **Detalle de juego** (`detalle.jsx`) en `/juegos/[id]`: portada, tags, descripción, stat-strip (partidas, mejor global, dificultad), leaderboard lateral con `seededScores`, CTA a jugar y volver.
- Pantalla **Reproductor** (`reproductor.jsx`) en `/juegos/[id]/jugar`: HUD (jugador, puntuación, vidas, nivel), "cabinet" CRT visual con escena estática de enemigos/nave, controles de pausa/fin/salir, loop de demo (incremento de puntuación simulado, sin lógica de juego real) y modal de fin de partida con guardado de puntuación en `localStorage`.
- Pantalla **Salón de la Fama** (`salon.jsx`) en `/salon-de-la-fama`: tabs por juego, podio top 3, tabla completa de puntuaciones, siempre en estado invitado (sin fila "tu mejor marca").
- **Nav** compartido (`nav.jsx`) como layout: logo, enlaces a Biblioteca y Salón de la Fama, contador de créditos fijo, botón "Iniciar Sesión" inerte (sin acción), menú hamburguesa/mobile con backdrop.
- **Footer** compartido con el texto y estilo del template.
- Fondo animado (`av-bg`: grid en perspectiva + scanlines + viñeta) aplicado globalmente.
- Theming completo del template (colores neón, tipografía pixel/mono, animaciones, tarjetas, botones, modal) portado tal cual a `app/globals.css`.
- Tipografías **Press Start 2P** y **JetBrains Mono** vía `next/font/google`, reemplazando Geist/Geist Mono.
- Capa de datos mock tipada en `lib/data.ts`: `GAMES`, `CATS`, `PLAYERS`, `seededScores`, tipo `Game`.

**Out of scope (para specs futuros):**

- Pantalla **Auth** (`auth.jsx`) — login/registro real o simulado. El botón "Iniciar Sesión" del Nav queda como elemento visual sin destino ni acción.
- Cualquier lógica de juego real (colisiones, físicas, reglas por juego). El "loop" del Reproductor es una animación de demostración, no un juego jugable.
- Lectura de puntuaciones guardadas en `localStorage` (`av_scores`) desde cualquier pantalla — solo se escribe, nunca se lee de vuelta.
- Persistencia o autenticación en backend/servidor.
- Sonido/efectos de audio.
- Internacionalización — todo el contenido queda en español, igual que el template.

---

## Modelo de datos

Se porta `data.jsx` a TypeScript en `lib/data.ts`:

```ts
export interface Game {
  id: string;
  title: string;
  short: string;
  long: string;
  cat: "ARCADE" | "PUZZLE" | "SHOOTER" | "VERSUS";
  cover: string; // clase CSS de portada, p.ej. "cover-bricks"
  color: "cyan" | "magenta" | "yellow" | "green";
  best: number;
  plays: string;
}

export interface ScoreRow {
  rank: number;
  name: string;
  score: number;
  date: string;
}

export const GAMES: Game[];
export const CATS: string[]; // ["TODOS", "ARCADE", "PUZZLE", "SHOOTER", "VERSUS"]
export const PLAYERS: string[];
export function seededScores(seed: number, count?: number): ScoreRow[];
```

Convenciones:

- `id` de juego es el slug usado en la URL (`/juegos/bloque-buster`).
- `seededScores` es determinista (PRNG con seed numérica), igual que en el template — no usa `Math.random()` para las tablas de puntuaciones, sí lo usa el loop de demo del Reproductor.

---

## Plan de implementación

1. Crear `lib/data.ts` con el tipo `Game`, `ScoreRow` y los datos/función portados de `data.jsx`. Verificación manual: el archivo compila con `tsc --noEmit` (o build de Next) sin errores de tipos.
2. Actualizar `app/layout.tsx`: cargar `Press Start 2P` y `JetBrains Mono` con `next/font/google` como variables CSS, y portar el contenido de `styles.css` a `app/globals.css` (variables de tema, reset, `.av-bg`, componentes base como `.btn`, `.card`, `.chip`, animaciones). Agregar la capa de fondo `av-bg` y el `<footer>` estático en el layout. Verificación: `npm run dev` sirve `/` sin errores de consola, con el fondo neón y la tipografía pixel visibles.
3. Crear `components/Nav.tsx` (client component) portando `nav.jsx`: logo, links activos por ruta actual (`usePathname`), contador de créditos, botón "Iniciar Sesión" inerte, menú mobile con estado `open`. Insertarlo en `app/layout.tsx`. Verificación: el nav aparece en todas las rutas, el menú mobile abre/cierra con el hamburguesa.
4. Crear `components/GameCard.tsx` (client component) con el efecto tilt de `biblioteca.jsx`, y `app/page.tsx` con el hero, buscador, chips de categoría y grid, usando `GAMES`/`CATS` de `lib/data.ts` y enlazando cada tarjeta a `/juegos/[id]`. Verificación: buscar y filtrar por categoría funciona client-side; el estado vacío se muestra cuando no hay resultados.
5. Crear `app/juegos/[id]/page.tsx` portando `detalle.jsx`: busca el juego por `id`, muestra portada/tags/descripción/stat-strip, genera el leaderboard con `seededScores`, y enlaza a `/juegos/[id]/jugar` y a `/`. Si el `id` no existe, usar `notFound()` de Next.js. Verificación: navegar desde una tarjeta de la Biblioteca abre el detalle correcto; un `id` inválido da 404.
6. Crear `app/juegos/[id]/jugar/page.tsx` (client component) portando `reproductor.jsx`: HUD, arena CRT visual, pausa/fin/salir, loop de demo con `setInterval`, modal de fin con input de nombre y botón que escribe en `localStorage` (`av_scores`) y muestra el toast "PUNTUACIÓN GUARDADA". Verificación: la puntuación sube sola, pausar detiene el incremento, "FIN" abre el modal, guardar puntuación muestra el toast y agrega una entrada en `localStorage`.
7. Crear `app/salon-de-la-fama/page.tsx` (client component) portando `salon.jsx`: tabs por juego, podio top 3, tabla completa vía `seededScores`, siempre en estado invitado (sin la fila "tu mejor marca"), botón de volver a la Biblioteca. Verificación: cambiar de tab recalcula podio y tabla; nunca aparece la fila de usuario.

---

## Criterios de aceptación

- [ ] `npm run dev` sirve `/`, `/juegos/[id]`, `/juegos/[id]/jugar` y `/salon-de-la-fama` sin errores en consola del navegador.
- [ ] `npm run build` y `npm run lint` pasan sin errores.
- [ ] La Biblioteca muestra las 8 tarjetas de `GAMES`, filtra por texto y por categoría, y muestra el estado "NO HAY RESULTADOS" cuando no hay coincidencias.
- [ ] Hacer clic en una tarjeta (o en su botón "JUGAR") navega a `/juegos/<id>` con los datos del juego correcto.
- [ ] El Detalle muestra un leaderboard de 10 filas generado con `seededScores` y el botón "JUGAR AHORA" navega al Reproductor.
- [ ] Un `id` de juego inexistente en `/juegos/[id]` devuelve 404.
- [ ] En el Reproductor, la puntuación aumenta automáticamente cada ~220ms mientras no está en pausa ni terminado.
- [ ] El botón "PAUSA"/"REANUDAR" detiene y reanuda el incremento de puntuación.
- [ ] El botón "FIN" abre el modal de fin de partida con la puntuación final.
- [ ] Escribir un nombre y pulsar "GUARDAR PUNTUACIÓN" agrega una entrada a `localStorage["av_scores"]` y muestra el toast "PUNTUACIÓN GUARDADA_".
- [ ] "JUGAR DE NUEVO" reinicia puntuación, vidas, nivel y cierra el modal; "VOLVER AL VAULT" navega a `/`.
- [ ] El Salón de la Fama muestra un podio (2º, 1º, 3º) y una tabla de 12 filas que cambian al seleccionar otro tab de juego.
- [ ] El Salón de la Fama nunca muestra la fila "tu mejor marca" (no hay sesión en este MVP).
- [ ] El Nav aparece en las cuatro rutas, resalta el link activo, y su botón "Iniciar Sesión" no navega ni cambia de estado al hacer clic.
- [ ] El menú mobile del Nav abre con el botón hamburguesa y cierra al tocar el backdrop o un link.
- [ ] El fondo animado (`av-bg`) y las tipografías Press Start 2P/JetBrains Mono son visibles en las cuatro rutas.

---

## Decisiones

- **Sí:** excluir la pantalla Auth de este MVP. Implica manejo de sesión que no existe todavía; el botón del Nav queda como elemento visual inerte.
- **No:** enlazar el botón "Iniciar Sesión" a una ruta `/login` inexistente. Se prefiere un botón sin acción antes que un 404 accesible desde la navegación principal.
- **Sí:** rutas en español alineadas al template (`/juegos/[id]`, `/juegos/[id]/jugar`, `/salon-de-la-fama`) en vez de nombres en inglés, para mantener consistencia con el copy y el dominio del producto.
- **Sí:** portar `styles.css` tal cual a `app/globals.css` en vez de reescribir con utilidades Tailwind v4. El diseño del template es específico (neón, CRT, pixel-art) y reescribirlo en utilidades arriesga desviarse del resultado visual sin aportar valor en este MVP.
- **Sí:** reemplazar Geist/Geist Mono por Press Start 2P/JetBrains Mono vía `next/font/google`, siguiendo el patrón ya usado en `app/layout.tsx` para exponer variables CSS en `<html>`.
- **Sí:** mantener el loop de demo del Reproductor (incremento de puntuación con `setInterval`, subida de nivel, pausa). No es lógica de juego real —es una animación que simula actividad— y forma parte de la experiencia visual del template.
- **Sí:** guardar en `localStorage` al final de una partida demo, igual que el template, sin leerlo de vuelta en ninguna pantalla de este MVP. Mantiene el flujo visual completo (incluido el toast de confirmación) sin requerir una fuente de verdad para puntuaciones reales.
- **No:** persistir o leer sesión de usuario. Sin Auth no hay concepto de usuario logueado; el Salón de la Fama y el Nav siempre están en estado invitado.
- **Sí:** centralizar los datos mock tipados en `lib/data.ts` en vez de duplicarlos por pantalla, para tener una única fuente de verdad reutilizable entre Biblioteca, Detalle, Reproductor y Salón de la Fama.

---

## Riesgos

| Riesgo | Mitigación |
| --- | --- |
| El reset/base de Tailwind v4 (`@tailwindcss/postcss`) puede chocar con el CSS portado del template (que trae su propio reset). | Verificar visualmente cada pantalla tras portar `styles.css`; si hay conflictos, acotar el reset de Tailwind o cargarlo después del CSS del template. |
| `localStorage` no disponible (modo privado estricto o SSR). | El guardado en el Reproductor es un cliente-only best-effort envuelto en `try/catch`, igual que en el template original; si falla, el flujo visual (toast) igual se muestra. |
| Fuentes pixel (`Press Start 2P`) muy pequeñas afectan legibilidad en mobile. | Se respeta el mismo `font-size` y jerarquía que ya define el template, que fue diseñado pensando en este contraste de tipografías. |

---

## Lo que **no** está en este spec

- Pantalla de Auth (login/registro), real o simulada.
- Lógica de juego jugable para cualquiera de los 8 juegos listados.
- Lectura de puntuaciones guardadas en `localStorage`.
- Backend, base de datos o autenticación real.
- Sonido, i18n, o modo claro.

Cada uno de estos, si se implementa, va en su propio spec.
