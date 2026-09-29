# SPEC 03 — Acerca de (About + Contacto) de Arcade Vault

> **Estado:** Implmentado
> **Depende de:** SPEC 01, SPEC 02
> **Fecha:** 2026-09-29
> **Objetivo:** Portar a Next.js App Router la pantalla Acerca de (misión, highlights y formulario de contacto simulado) definida en `references/resources/resources/templates/home-about/home-about/about.jsx`, en la ruta `/acerca-de`, y añadir el 4º link "Acerca de" al Nav.

---

## Por qué existe este spec

SPEC 02 portó Home y dejó explícitamente fuera `about.jsx` (con su formulario de contacto y el 4º link del Nav) para un spec propio. Este spec cierra ese pendiente. El formulario tiene lógica de estado (validación, shake, pantalla de éxito estilo terminal) que se define aquí para no improvisarla durante la implementación.

---

## Scope

**In:**

- Nueva ruta `/acerca-de` en `app/acerca-de/page.tsx` (client component, por el estado del formulario), portando `About` de `about.jsx`:
  - **Hero**: kicker "▸ ACERCA DE", título "ACERCA DE ARCADE VAULT", párrafo de misión y fila de 3 `highlight` (HEART/magenta, BROWSER/cyan, PLANT/green) con el texto del template y `transitionDelay` escalonado.
  - **Divisor decorativo** (`about-divider`): barra + 24 píxeles con `animationDelay` + barra, con `aria-hidden` y `reveal`.
  - **Sección Contacto**: intro (kicker "▸ CONTACTO", título "CONTÁCTANOS", subtítulo y 3 `tip` con LED: "RESPUESTA EN 24-48H", "SUGERENCIAS BIENVENIDAS", "SIN SPAM, JAMÁS") y formulario con campos NOMBRE, CORREO ELECTRÓNICO (`type="email"`) y MENSAJE (`textarea`, 5 filas), con los placeholders del template.
  - **Validación idéntica al template**: si cualquiera de los 3 campos está vacío tras `trim()`, el formulario hace `shake` 400 ms y no envía; sin mensajes de error por campo. El formato del email solo lo valida el navegador vía `type="email"`.
  - **Envío simulado**: con los 3 campos válidos se reemplaza el formulario por la pantalla de éxito `terminal-success` (barra con 3 puntos + "VAULT-OS // TERMINAL", líneas `[OK]`, y "MENSAJE RECIBIDO… GRACIAS, {NOMBRE EN MAYÚSCULAS}." con caret parpadeante). Nada se envía ni se guarda.
  - Botón "ENVIAR OTRO MENSAJE" en la pantalla de éxito: vuelve al formulario con los 3 campos vacíos.
  - Componente `HighlightIcon` (HEART, BROWSER, PLANT) como función local de la página, igual que `FeatureIcon` en Home.
  - Animación `reveal`-on-scroll con el hook existente `lib/useReveal.ts`.
- Actualizar `components/Nav.tsx`: añadir el 4º link "Acerca de" (`/acerca-de`) en desktop y en el menú mobile, con resaltado activo cuando `pathname === "/acerca-de"`.
- Portar a `app/globals.css` las reglas del template que faltan para Acerca de: `.about`, `.about-hero`, `.about-title`, `.about-mission`, `.highlight-row`/`.highlight`/`.hl-icon`/`.hl-text`, `.about-divider`/`.div-bar`/`.div-pixels`, `@keyframes pxblink`, `.about-contact`, `.contact-grid`, `.contact-intro`, `.contact-title`, `.contact-sub`, `.contact-tips`/`.tip`/`.tip-led`, `.contact-form` (+ `::before`, `.shake`, `@keyframes shake`, `textarea`, placeholders), `.btn.press`, `.terminal-success`, `.term-bar`, `.term-body`.

**Out of scope (para specs futuros):**

- Envío real del formulario (Route Handler, email, base de datos) y cualquier persistencia del mensaje (incluido `localStorage`).
- Mensajes de error por campo o validación de email más estricta que `type="email"`.
- Auth: el botón "Iniciar Sesión" del Nav sigue inerte, igual que en SPEC 01 y 02.
- Cualquier contenido nuevo no presente en `about.jsx` (equipo, historia, redes sociales, FAQ).
- Sonido, i18n o lógica de juego (ya excluidos desde SPEC 01).

---

## Modelo de datos

No se introduce ningún dato persistente ni reutilizable. El estado del formulario vive solo en el componente de la página:

```ts
const [form, setForm] = useState({ name: "", email: "", msg: "" });
const [sent, setSent] = useState<string | null>(null); // nombre (trim) tras envío simulado
const [shake, setShake] = useState(false);
```

Convenciones:

- `sent === null` muestra el formulario; `sent` con valor muestra la pantalla de éxito.
- Los textos del hero, highlights y tips son literales del template, sin tipar como modelo reutilizable.

---

## Plan de implementación

1. Portar a `app/globals.css` las reglas CSS de Acerca de listadas en el scope, copiándolas de `references/resources/resources/templates/home-about/home-about/styles.css` (líneas ~1072–1200 y `.btn.press`). No duplicar lo que ya existe (`.field`, `.field input`, `.kicker`, `.btn.xl`, `@keyframes blink`, `.neon-*`). Verificación: `npm run dev` sigue sirviendo `/`, `/biblioteca` y `/salon-de-la-fama` sin cambios visuales ni errores.
2. Crear `app/acerca-de/page.tsx` con el hero (kicker, título, misión), `HighlightIcon` y la fila de 3 highlights, más el divisor decorativo, usando `useReveal`. Verificación: `/acerca-de` muestra hero y divisor igual que en el template.
3. Añadir a la misma página la sección Contacto: intro con los 3 tips y formulario controlado con validación por `trim()` y `shake`. Verificación: enviar con algún campo vacío hace shake y no cambia de vista; con un email mal formado el navegador bloquea el envío.
4. Añadir la pantalla de éxito `terminal-success` y el botón "ENVIAR OTRO MENSAJE". Verificación: enviar con datos válidos muestra el terminal con el nombre en mayúsculas; el botón vuelve al formulario vacío.
5. Actualizar `components/Nav.tsx` con el 4º link "Acerca de" en desktop y mobile y su estado activo. Verificación: en `/acerca-de` el link queda resaltado y los otros 3 links siguen resaltándose correctamente en sus rutas.
6. En la página home el div que contiene la palabra "DESLIZA" se debe correr hacia abajo porque se translapa con los botones superiores.
7. Verificar en navegador con Playwright MCP (capturas en `.playwright-screenshots/`, según `CLAUDE.md`) que `/acerca-de` coincide visualmente con el template en desktop y mobile, y correr `npm run build` y `npm run lint`.

---

## Criterios de aceptación

- [x] `npm run dev` sirve `/acerca-de` con hero, divisor y sección de contacto, sin errores de consola.
- [x] El Nav muestra 4 links (Inicio, Biblioteca, Salón de la Fama, Acerca de) en desktop y en el menú mobile.
- [x] En `/acerca-de` solo el link "Acerca de" está resaltado; en `/`, `/biblioteca`, `/juegos/[id]` y `/salon-de-la-fama` no lo está.
- [x] Los 3 highlights muestran los iconos HEART, BROWSER y PLANT con los colores magenta, cyan y green.
- [x] Enviar el formulario con cualquier campo vacío (o solo espacios) activa el `shake` durante ~400 ms y mantiene el formulario visible.
- [x] Un email sin formato válido es rechazado por el navegador antes de llegar a la lógica de envío.
- [x] Enviar con los 3 campos válidos muestra la pantalla `terminal-success` con "GRACIAS, {NOMBRE EN MAYÚSCULAS}."
- [x] "ENVIAR OTRO MENSAJE" vuelve al formulario con nombre, correo y mensaje vacíos.
- [x] Enviar el formulario no realiza ninguna petición de red ni escribe en `localStorage`.
- [x] Las secciones con `reveal` (divisor y contacto) se activan al hacer scroll.
- [x] En ≤900 px el `contact-grid` pasa a una columna.
- [x] `/`, `/biblioteca`, `/juegos/[id]`, `/juegos/[id]/jugar` y `/salon-de-la-fama` se ven igual que antes de este spec (salvo el nuevo link del Nav).
- [x] `npm run build` y `npm run lint` pasan sin errores.

---

## Decisiones

- **Sí:** ruta `/acerca-de`. Coherente con `/biblioteca` y `/salon-de-la-fama` (rutas en español) y con el label "Acerca de" del Nav.
- **No:** `/about`. Coincide con el nombre del componente del template, pero rompe la convención de rutas del proyecto.
- **Sí:** envío simulado sin persistencia, idéntico al template. Ninguna pantalla consume los mensajes, así que guardarlos añadiría modelo de datos sin uso.
- **No:** guardar en `localStorage` ni crear un Route Handler `/api/contact`. Un envío real necesita decidir destino (email/DB) y anti-spam; va en su propio spec.
- **Sí:** validación idéntica al template (`trim()` + shake, sin mensajes por campo). Es lo que pide el usuario ("igual que el template") y evita diseñar estilos de error nuevos.
- **No:** mensajes de error por campo. Se pueden añadir en un spec de mejora de formularios si hace falta.
- **Sí:** 4º link "Acerca de" en desktop y mobile, como en el template y como anunció SPEC 02.
- **Sí:** la página es un client component (`"use client"`) completo. El estado del formulario y `useReveal` lo requieren; la página es pequeña y no hay contenido que se beneficie de SSR separado.
- **Sí:** `HighlightIcon` como función local de la página, siguiendo el patrón de `FeatureIcon` en Home, en vez de un componente compartido (solo se usa aquí).
- **Sí:** reutilizar `.field`, `.field input`, `.kicker` y `.btn.xl` ya presentes en `globals.css` en vez de copiarlos de nuevo.

---

## Riesgos

| Riesgo | Mitigación |
| --- | --- |
| Copiar CSS del template duplica o pisa reglas ya existentes (`.field`, `.field input`, `.btn.xl`, `@keyframes blink`). | Antes de pegar, grep de cada selector en `app/globals.css`; solo se añaden los que faltan. Verificar que Auth/Detalle/Salón no cambian visualmente. |
| `.field textarea` no existe en `globals.css`; el template solo estiliza el `textarea` dentro de `.contact-form`. | Portar la regla `.contact-form textarea` tal cual, con alcance limitado a `.contact-form`. |
| El `shake` con `setTimeout` puede disparar `setState` tras desmontar la página. | Limpiar el timeout en un `useEffect` o `useRef`, o aceptar que React 19 ignora el update sin efecto visible; verificar sin warnings en consola. |
| El nombre en la pantalla de éxito se muestra en mayúsculas desde texto libre del usuario. | Se renderiza como texto de React (escapado por defecto); no usar `dangerouslySetInnerHTML`. |

---

## Lo que **no** está en este spec

- Envío real del formulario o persistencia de mensajes.
- Mensajes de error por campo o validación de email avanzada.
- Flujo de Auth real o simulado.
- Contenido adicional a `about.jsx` (equipo, redes, FAQ).
- Lógica de juego, sonido o i18n.

Cada uno de estos, si se implementa, va en su propio spec.
