# SPEC 05 — Juego real: Rocas (Asteroids)

> **Estado:** Aprobado
> **Depende de:** SPEC 01
> **Fecha:** 2026-10-05
> **Objetivo:** Portar el prototipo standalone de `references/resources/resources/started-games/02-asteroids/game.js` a un módulo TypeScript que se monta dentro del `<canvas>` del Reproductor (`/juegos/rocas/jugar`), reemplazando el loop de demo por el juego real para el título "ROCAS" de `lib/data.ts`, sin tocar el resto de juegos ni otras pantallas.

---

## Por qué existe este spec

SPEC 01 implementó el Reproductor (`/juegos/[id]/jugar`) como una simulación: HUD con datos reales (score/vidas/nivel en React) pero una escena puramente decorativa (`div.game-arena` con CSS) y un `setInterval` que sube el puntaje al azar. `references/resources/resources/started-games/02-asteroids/` ya trae un juego de Asteroids completo y jugable en un solo archivo (`game.js`, canvas HTML5 puro, sin dependencias) que corresponde en tema y categoría al juego mock `rocas` (`SHOOTER`, "Pulveriza asteroides en gravedad cero") de `lib/data.ts`.

Este es el primer juego real que entra a la plataforma — después de este spec quedan pendientes, cada uno en su propio spec futuro, Tetris (`03-tetris` → mock `caida`) y Arkanoid (`04-arkanoid` → mock `bloque-buster`). Por eso este spec resuelve **solo** Rocas de forma concreta: no se diseña todavía una interfaz genérica para "montar cualquier juego", para no abstraer con un único caso real. Esa generalización se evalúa cuando se porte el segundo juego.

`game.js` es vanilla JS con estado a nivel de módulo (variables globales), listeners de teclado atados a `window` y un `initGame()` + `requestAnimationFrame(loop)` que se ejecutan al cargar el script — pensado para una página standalone que nunca se desmonta. El Reproductor es un componente cliente de Next.js que sí se monta/desmonta con la navegación del router, así que el juego debe envolverse en una función que expone un ciclo de vida explícito (crear, pausar, reiniciar, destruir) en vez de ejecutarse como efecto secundario de importar el archivo.

---

## Scope

**In:**

- `lib/games/asteroids.ts`: puerto de `game.js` completo (clases `Bullet`, `Asteroid`, `PowerUp`, `Ship`, `Particle`, constantes `RADII`/`SPEEDS`/`POINTS`/`POWERUP_*`/`TRIPLE_SPREAD`, utils `wrap`/`dist`/`rand`/`randInt`), incluyendo el power-up de triple disparo tal cual existe en el archivo original (no documentado en su README, pero parte del juego real).
- Una función `createAsteroidsGame(canvas, onState)` que:
  - Recibe el `HTMLCanvasElement` en vez de buscarlo con `getElementById`.
  - Agrega los listeners de teclado (`keydown`/`keyup`) sobre `window` al crearse y los remueve en `destroy()`.
  - Agrega soporte real de pausa (`setPaused(paused: boolean)`): mientras está en pausa, `update(dt)` no se ejecuta (la física, el input y las colisiones quedan congeladas); `draw()` sigue pintando el último frame.
  - Expone `restart()` (reinicia score/vidas/nivel/nave/asteroides, equivalente al `initGame()` original) y `forceGameOver()` (fuerza el estado `'gameover'` sin tocar las vidas, para terminar la partida manualmente).
  - Notifica cambios de estado (`score`, `lives`, `level`, `phase: 'playing' | 'dead' | 'gameover'`) a React vía `onState(state)`, llamado solo cuando alguno de esos valores cambia (no en cada frame) para no disparar renders de React a 60fps.
  - Expone `destroy()`: cancela el `requestAnimationFrame` pendiente y remueve los listeners de `window`.
- Actualizar `app/juegos/[id]/jugar/page.tsx` para el caso `game.id === "rocas"`:
  - Reemplazar el `div.game-arena` decorativo por un `<canvas>` real de 800×600 (mismo tamaño lógico que el original), escalado por CSS al tamaño de `.crt-screen` (que ya tiene `aspect-ratio: 4/3`, igual que 800×600, sin distorsión).
  - Quitar el `useEffect` del `setInterval` demo para este juego; en su lugar, montar `createAsteroidsGame` en un efecto, guardar el handle devuelto, y sincronizar `score`/`lives`/`level` de React desde `onState`.
  - Cuando `onState` reporta `phase === "gameover"`, abrir el modal de fin de partida igual que hoy (mismo flujo de guardado en `localStorage["av_scores"]`, sin cambios de forma/clave respecto a SPEC 01).
  - El botón "PAUSA"/"REANUDAR" llama a `handle.setPaused(...)` además de actualizar el overlay visual "EN PAUSA" que ya existe.
  - El botón "FIN" llama a `handle.forceGameOver()` (en vez de abrir el modal directamente); el modal se abre vía el mismo callback `onState` que usa el game-over real.
  - "JUGAR DE NUEVO" llama a `handle.restart()` además de resetear el estado de React del modal.
  - El cleanup del efecto (desmontaje o cambio de ruta) llama a `handle.destroy()`.
- Preservar el `preventDefault()` en `keydown` para `ArrowLeft`/`ArrowRight`/`ArrowUp`/`Space` dentro del módulo portado, para que jugar no haga scroll de la página (el original no lo necesitaba porque era la única página del sitio).

**Out of scope (para specs futuros):**

- Cualquier cambio a los otros 7 juegos de `lib/data.ts` (`bloque-buster`, `caida`, `serpentina`, `gloton`, `invasores`, `ranaria`, `duelo-pixel`). Sus rutas `/juegos/<id>/jugar` siguen mostrando el `game-arena` decorativo y el loop de demo de SPEC 01 sin ningún cambio.
- Una interfaz/contrato genérico para "montar cualquier juego" en el Reproductor. Se diseña cuando se porte el segundo juego real (Tetris o Arkanoid).
- Quitar la duplicación entre el HUD que `game.js` dibuja dentro del canvas (SCORE/NIVEL/vidas) y la barra HUD de React que ya existe por encima del CRT — ambos quedan mostrando los mismos datos reales, sin modificar el dibujado interno del juego.
- Controles táctiles/móviles. El juego portado sigue siendo solo teclado, igual que el original.
- Leyenda visible de controles (↑/←/→/Espacio) en la pantalla del Reproductor.
- Leer de vuelta `localStorage["av_scores"]` en cualquier pantalla (sigue sin leerse, decisión ya tomada en SPEC 01).
- Cambiar el `best`/leaderboard estático de la pantalla de Detalle (`/juegos/rocas`) para reflejar partidas reales. Sigue siendo mock (`seededScores`).
- Sonido/efectos de audio, i18n, modo claro.
- Dificultad/balance distinto al original: tamaños, velocidades, puntos (`RADII`/`SPEEDS`/`POINTS`), cantidad de asteroides por nivel y probabilidad/duración del power-up se portan sin modificar.

---

## Modelo de datos

No se introduce persistencia nueva — se reutiliza tal cual la forma de `localStorage["av_scores"]` ya definida en SPEC 01 (`{ game, score, name, at }`).

Lo que sí se introduce es el contrato del módulo portado, en `lib/games/asteroids.ts`:

```ts
export type AsteroidsPhase = "playing" | "dead" | "gameover";

export interface AsteroidsState {
  score: number;
  lives: number;
  level: number;
  phase: AsteroidsPhase;
}

export interface AsteroidsGameHandle {
  setPaused(paused: boolean): void;
  restart(): void;
  forceGameOver(): void;
  destroy(): void;
}

export function createAsteroidsGame(
  canvas: HTMLCanvasElement,
  onState: (state: AsteroidsState) => void,
): AsteroidsGameHandle;
```

Convenciones:

- `onState` se invoca solo cuando `score`, `lives`, `level` o `phase` cambian respecto al último valor notificado (comparación por snapshot), no en cada frame del loop.
- `phase` mapea 1:1 al `state` interno de `game.js` (`'playing' | 'dead' | 'gameover'`); `'dead'` es el breve período de reaparición con parpadeo que ya existe en el original, no un estado nuevo.
- `forceGameOver()` deja `lives` como esté (no las pone en 0) — solo cambia `phase` a `'gameover'` para abrir el modal de fin de partida voluntariamente.

---

## Plan de implementación

1. Crear `lib/games/asteroids.ts` portando `game.js` dentro de `createAsteroidsGame(canvas, onState)`:
   - Mover `ctx`, `keys`, `justPressed`, y todo el estado de módulo (`ship`, `bullets`, `asteroids`, `particles`, `powerUps`, `score`, `lives`, `level`, `state`, `deadTimer`, `powerUpSpawned`, `killsSinceSpawn`) al closure de la función, sin variables globales.
   - Agregar los listeners `keydown`/`keyup` sobre `window` al llamar `createAsteroidsGame`, con `e.preventDefault()` para los 4 códigos usados por el juego.
   - Agregar un flag `paused`; en el `loop(ts)`, si `paused` es `true`, se saltea la llamada a `update(dt)` (pero se sigue llamando `draw()`), y al reanudar se resetea `lastTime = null` para no aplicar un `dt` gigante.
   - Quitar del bloque `state === 'gameover'` el reinicio automático con `pressed('Space')` (`if (pressed('Space')) initGame()`): al llegar a `'gameover'`, el juego se queda congelado hasta que React llame `restart()`.
   - Agregar `forceGameOver()` que pone `state = 'gameover'` directamente.
   - Al final de cada `update(dt)`, comparar `{score, lives, level, phase: state}` contra el último snapshot enviado y llamar `onState(...)` solo si cambió.
   - `destroy()` cancela el `requestAnimationFrame` pendiente (guardar su id) y remueve los 2 listeners de `window`.
   - Verificación: `npm run build` compila sin errores de tipos (el módulo no se usa todavía, así que no hay verificación visual en este paso).

2. Actualizar `app/juegos/[id]/jugar/page.tsx`:
   - Para `game.id === "rocas"`: agregar un `useRef<HTMLCanvasElement>(null)` y un `useRef<AsteroidsGameHandle | null>(null)`; en un `useEffect` (dependiente de `game.id`), si el canvas existe, llamar `createAsteroidsGame(canvas, onState)` y guardar el handle; el cleanup del efecto llama `handle.destroy()`.
   - `onState` actualiza `score`/`lives`/`level` con `setScore`/`setLives`/`setLevel`, y si `phase === "gameover"` llama `setOver(true)`.
   - Reemplazar, solo para `rocas`, el `div.game-arena` dentro de `.crt-screen` por `<canvas ref={canvasRef} width={800} height={600} style={{ width: "100%", height: "100%" }} />`. Para cualquier otro `id`, se deja el `div.game-arena` decorativo actual sin cambios.
   - Quitar, solo para `rocas`, el `useEffect` del `setInterval` demo (los demás juegos lo conservan).
   - El botón "PAUSA"/"REANUDAR": además de `setPaused((p) => !p)` de React (que sigue controlando el overlay visual), llama `handleRef.current?.setPaused(!paused)` cuando `game.id === "rocas"`.
   - El botón "FIN": para `rocas`, llama `handleRef.current?.forceGameOver()` en vez de `setOver(true)` directo; para los demás juegos, sigue llamando `endGame()` como hoy.
   - "JUGAR DE NUEVO": para `rocas`, además de `restart()` (el de React que resetea `paused`/`over`/`saved`), llama `handleRef.current?.restart()`.
   - `saveScore()` no cambia: sigue escribiendo `{ game: game.id, score, name, at: Date.now() }` en `localStorage["av_scores"]`, ahora con el `score` real sincronizado desde el juego.
   - Verificación manual (Playwright MCP, captura en `.playwright-screenshots/`): abrir `/juegos/rocas/jugar`, confirmar que aparece el canvas real dentro del CRT; las flechas rotan/propulsan la nave y Espacio dispara; destruir un asteroide grande lo divide y la puntuación sube en la barra HUD; "PAUSA" congela el juego de verdad; perder las 3 vidas abre el modal con el score real; "FIN" también lo abre en cualquier momento; guardar puntuación agrega una fila a `localStorage`; "JUGAR DE NUEVO" reinicia el juego real; navegar a otra ruta no deja el loop corriendo en segundo plano (sin warnings de React en consola). Repetir una verificación rápida en `/juegos/caida/jugar` (u otro juego no portado) para confirmar que sigue mostrando el demo sin cambios.

---

## Criterios de aceptación

- [ ] `lib/games/asteroids.ts` existe y exporta `createAsteroidsGame`, `AsteroidsState`, `AsteroidsPhase` y `AsteroidsGameHandle`.
- [ ] `npm run build` pasa sin errores de tipos ni de lint.
- [ ] `/juegos/rocas/jugar` renderiza un `<canvas>` real dentro del CRT en vez del `div.game-arena` decorativo.
- [ ] Las flechas izquierda/derecha rotan la nave, la flecha arriba propulsa (con llama visible), y Espacio dispara balas, todo dentro del canvas.
- [ ] Destruir un asteroide grande lo divide en 2 medianos, un mediano en 2 pequeños, y un pequeño no se divide. La puntuación sube según `POINTS` (20/50/100) y el nuevo valor se refleja en la barra "Puntuación" de React.
- [ ] El power-up de triple disparo (recolectable cian pulsante) puede aparecer tras destruir asteroides y expira solo tras unos segundos, igual que en el original.
- [ ] Al quedarse sin vidas, el modal "FIN DEL JUEGO" se abre automáticamente con la puntuación real acumulada.
- [ ] El botón "FIN" también abre el modal en cualquier momento, con la puntuación acumulada hasta ese instante, sin esperar a perder las vidas.
- [ ] El botón "PAUSA"/"REANUDAR" detiene y reanuda el juego de verdad (la nave y los asteroides dejan de moverse mientras está en pausa, no solo visualmente).
- [ ] "JUGAR DE NUEVO" reinicia el juego real (nave al centro, vidas en 3, nivel en 1, score en 0, asteroides regenerados) y cierra el modal.
- [ ] Navegar fuera de `/juegos/rocas/jugar` (o recargar) detiene el loop del juego sin dejar listeners de teclado activos ni warnings de React en consola por actualizar estado tras desmontar.
- [ ] Guardar puntuación agrega una entrada real a `localStorage["av_scores"]`, con la misma forma que antes de este spec.
- [ ] Las otras 7 rutas `/juegos/<id>/jugar` siguen mostrando el loop de demo sin ningún cambio visual ni de comportamiento.
- [ ] `npm run build` pasa (sirve como type-check, no hay script `tsc` separado).

---

## Decisiones

- **Sí:** resolver solo "Rocas" en este spec, sin diseñar todavía una interfaz genérica para montar cualquier juego. Es el primer juego real portado; abstraer con un único caso arriesga un contrato equivocado que haya que rehacer con Tetris/Arkanoid.
- **No:** crear ya un `GameModule` o contrato común entre juegos. Se evalúa cuando exista un segundo caso real.
- **Sí:** nombrar el módulo `lib/games/asteroids.ts` (según la carpeta de referencia `started-games/02-asteroids`) en vez de `rocas.ts` (el id usado en `lib/data.ts`/rutas). El nombre del archivo sigue la fuente portada; el mapeo `id === "rocas"` vive en `page.tsx`.
- **No:** dejar el HUD interno del canvas (SCORE/NIVEL/vidas, overlay de GAME OVER) y la barra HUD de React mostrando lo mismo sin unificarlos. Quedan duplicados a propósito — no se modifica el dibujado interno del juego portado.
- **Sí:** que el estado real `'gameover'` (0 vidas) y el botón manual "FIN" abran el mismo modal de guardado de puntuación, vía el mismo callback `onState`. Es más fiel al juego real que dejar el "FIN" como única vía.
- **Sí:** agregar soporte real de pausa al módulo portado (el original no lo tenía) para que el botón y el overlay "EN PAUSA" que ya existen en el Reproductor sigan funcionando de verdad y no solo visualmente.
- **Sí:** portar `game.js` completo, incluyendo el power-up de triple disparo no documentado en su README. Es el juego real ya probado; quitar piezas sin motivo arriesga el balance sin necesidad.
- **No:** agregar leyenda visible de controles ni soporte táctil/móvil en este spec. El juego original es solo teclado y sin instrucciones en pantalla; se mantiene así.
- **Sí:** canvas con resolución lógica fija 800×600 (igual que el original) escalado por CSS a `width: 100%; height: 100%` dentro de `.crt-screen`, que ya tiene `aspect-ratio: 4/3` — coincide exactamente con 800×600, sin distorsión ni necesidad de lógica de resize en JS.
- **Sí:** quitar del juego portado el reinicio automático al presionar Espacio en pantalla de game over (`pressed('Space')` dentro de `update()`), porque ese flujo ahora lo controla el modal de React (nombre + "GUARDAR PUNTUACIÓN" / "JUGAR DE NUEVO").
- **Sí:** `preventDefault()` en `keydown` para las 4 teclas usadas (flechas y espacio), para que jugar no haga scroll de la página — el original no lo necesitaba porque no convivía con una página con más contenido.
- **No:** cambiar `RADII`, `SPEEDS`, `POINTS`, cantidad de asteroides por nivel, ni la probabilidad/duración del power-up. Se portan sin modificar.

---

## Riesgos

| Riesgo                                                                                                                                                                                                                 | Mitigación                                                                                                                                                                                                 |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| En desarrollo, el modo estricto de React puede montar/desmontar el efecto dos veces, creando dos instancias del juego con listeners duplicados.                                                                        | `destroy()` es idempotente y cancela su propio `requestAnimationFrame`/listeners; el `useEffect` solo guarda un handle a la vez y llama `destroy()` en el cleanup antes de crear uno nuevo.                |
| Los listeners de teclado quedan atados a `window`: si `destroy()` no se llama (navegación abrupta, error no controlado), el juego sigue corriendo en segundo plano y consumiendo CPU/escuchando teclas en otras rutas. | Cleanup del `useEffect` siempre invoca `destroy()`; se verifica manualmente navegando fuera de la página y revisando que no haya warnings de React en consola ni CPU alta en DevTools.                     |
| `preventDefault()` en las 4 teclas del juego podría bloquear accesos de teclado legítimos de la página (p. ej. si el foco está en el input de nombre del modal de fin de partida).                                     | El modal solo se abre cuando `phase === "gameover"`, momento en el que el juego ya está congelado y no vuelve a leer `keys`/`justPressed`; el listener sigue activo pero no tiene efecto sobre la partida. |
| Canvas fijo en 800×600 escalado por CSS puede verse borroso en pantallas de alta densidad (`devicePixelRatio` > 1).                                                                                                    | Mismo tamaño lógico que el juego original; no se introduce lógica de `devicePixelRatio` en este spec — se deja como posible mejora visual futura, no bloquea la jugabilidad.                               |

---

## Lo que **no** está en este spec

- Portar Tetris (`03-tetris` → mock `caida`) o Arkanoid (`04-arkanoid` → mock `bloque-buster`).
- Una interfaz/contrato genérico para montar cualquier juego en el Reproductor.
- Unificar el HUD interno del canvas con la barra HUD de React.
- Controles táctiles/móviles ni leyenda visible de controles en pantalla.
- Leer de vuelta `localStorage["av_scores"]` en cualquier pantalla.
- Leaderboard o `best` reales para "Rocas" en la pantalla de Detalle — sigue siendo mock (`seededScores`).
- Sonido, i18n, modo claro, soporte de `devicePixelRatio`.

Cada uno de estos, si se implementa, va en su propio spec.
