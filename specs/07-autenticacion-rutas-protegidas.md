# SPEC 07 — Autenticación con Supabase Auth y rutas protegidas

> **Estado:** Implementado
> **Depende de:** SPEC 01, SPEC 04, SPEC 06
> **Fecha:** 2026-10-14
> **Objetivo:** Añadir registro e inicio de sesión con Supabase Auth (email/contraseña y OAuth con Google/GitHub) y proteger con `proxy.ts` toda la app salvo Inicio y Acerca de, de forma que jugar o ver el catálogo exija una cuenta confirmada.

---

## Por qué existe este spec

SPEC 04 instaló la infraestructura de Supabase pero dejó fuera de alcance explícitamente "Auth (login, registro, sesiones) y el `proxy.ts` de Next 16 que refresca la sesión", diciendo que "van juntos en el spec de Auth". SPEC 06 conectó el leaderboard real pero mantuvo `scores.name` como texto libre tecleado en el modal de fin de partida, sin relación con ninguna cuenta, y dejó la política de RLS de `games`/`scores` abierta a `anon` porque no existía ningún otro mecanismo de acceso.

Hoy el botón "Iniciar Sesión" del nav (`components/Nav.tsx`) es inerte y toda la app es pública. Este spec cierra ambos huecos: pantalla de autenticación real contra Supabase Auth, y un `proxy.ts` que convierte en obligatoria la sesión para todo excepto Inicio y Acerca de. El template de diseño `references/.../templates/auth.jsx` ya define la UI de referencia (tabs "Iniciar sesión" / "Crear cuenta", botones sociales, mensaje legal) — este spec la porta, adaptando el campo de login de "Usuario" a "Correo electrónico" porque Supabase Auth autentica por email, no por username.

---

## Scope

**In:**

- Activar en el proyecto de Supabase: confirmación de email obligatoria antes de poder iniciar sesión, y los providers de OAuth Google y GitHub (sin credenciales reales todavía — ver Decisiones y Riesgos).
- `app/auth/page.tsx` (client component), portado de `auth.jsx`: tabs "Iniciar sesión" / "Crear cuenta".
  - Tab "Iniciar sesión": campos Correo electrónico + Contraseña → `supabase.auth.signInWithPassword`. Éxito navega a `/biblioteca`. Error (credenciales inválidas, email sin confirmar, etc.) se muestra debajo del formulario con el mensaje que devuelve Supabase.
  - Tab "Crear cuenta": campos Usuario + Correo electrónico + Contraseña → `supabase.auth.signUp({ email, password, options: { data: { username } } })`. Tras éxito, en vez de navegar, se muestra un mensaje fijo ("revisa tu correo para confirmar la cuenta") porque la cuenta no puede iniciar sesión hasta confirmar el email.
  - Botones "Google" / "GitHub" → `supabase.auth.signInWithOAuth({ provider, options: { redirectTo: <origin>/auth/callback } })`.
  - Se elimina el botón "Jugar como invitado" del template: ya no existe acceso sin cuenta.
- `app/auth/callback/route.ts`: `GET` que recibe `code`, llama a `supabase.auth.exchangeCodeForSession(code)` con el cliente server y redirige a `/biblioteca` (o a `/auth?error=...` si falla).
- `proxy.ts` en la raíz del proyecto (convención de Next 16, ver `node_modules/next/dist/docs/01-app/01-getting-started/16-proxy.md`): refresca la sesión en cada request con el patrón de cookies de `@supabase/ssr`, y redirige a `/auth` cuando no hay sesión en cualquier ruta que no sea `/`, `/acerca-de`, `/auth`, `/auth/callback`, assets internos de Next o `/api/health/*`.
- `components/Nav.tsx`: deja de ser estático. Lee la sesión con el cliente browser y se suscribe a `supabase.auth.onAuthStateChange`. Con sesión muestra `{username o correo} ▾`; un click llama a `supabase.auth.signOut()` y redirige a `/`. Sin sesión muestra "Iniciar Sesión" enlazando a `/auth`.
- `app/juegos/[id]/jugar/page.tsx` (SPEC 06): el campo de nombre del modal de fin de partida se prellena (sigue editable) con `user_metadata.username` de la sesión activa en vez de arrancar vacío.
- Migración `supabase/migrations/20261014000000_scores_auth_only.sql`: sustituye las políticas de RLS de `games` y `scores` (creadas en SPEC 06) para que `SELECT` e `INSERT` exijan rol `authenticated`, retirando el acceso `anon` porque ya no hay ninguna pantalla que llegue a esas tablas sin sesión.
- Documentar en `README.md`: cómo se activa Auth en el proyecto, pasos manuales pendientes para dar de alta las OAuth apps de Google y GitHub y pegar sus credenciales en el dashboard de Supabase, la limitación del SMTP de prueba, y la lista de rutas públicas vs. protegidas. Actualizar `CLAUDE.md` para quitar la nota de que "Iniciar Sesión" está inerte.

**Out of scope (para specs futuros):**

- Flujo de "olvidé mi contraseña" / reset de contraseña.
- Tabla `profiles`, unicidad del campo Usuario o cualquier chequeo de disponibilidad de nombre.
- SMTP propio (Resend, SendGrid…) o dominio de email propio para los correos de confirmación.
- Cualquier pantalla de "Cuenta" o edición de perfil (cambiar username, avatar, borrar cuenta, cambiar contraseña).
- Vincular `scores` a `auth.users` (columna `user_id`, destacar "tu mejor marca" en el Salón de la Fama). El nombre solo se prellena; sigue siendo texto libre editable, igual que en SPEC 06.
- Rate limiting, CAPTCHA o cualquier protección anti-bot en el registro.
- Roles o niveles de permiso distintos entre usuarios autenticados.
- Cualquier modo de acceso sin cuenta (invitado, solo lectura) a Biblioteca, Detalle, Jugar o Salón de la Fama.

---

## Modelo de datos

Este spec no crea tablas nuevas. La única estructura nueva es la forma de los metadatos que Supabase Auth guarda por usuario:

```ts
// auth.users.raw_user_meta_data, fijado en signUp({ options: { data } })
{ username: string }
```

Convenciones:

- `username` es solo un display name libre, sin unicidad ni tabla propia — se lee con `supabase.auth.getUser()` (`data.user.user_metadata.username`).
- Las políticas de RLS de `games` y `scores` (antes abiertas a `anon`/`authenticated` en SPEC 06) pasan a exigir únicamente `authenticated`. No se edita la migración de SPEC 06; se añade una nueva que reemplaza las políticas.

---

## Plan de implementación

1. En el proyecto de Supabase, activar "Confirm email" en la configuración de Auth y dar de alta los providers Google y GitHub (sin credenciales reales todavía, quedan en estado "disabled" hasta que se configuren). Verificación: la configuración del proyecto refleja `confirm_email` activo.
2. Crear y aplicar `supabase/migrations/20261014000000_scores_auth_only.sql`, que reemplaza las políticas de RLS de `games`/`scores` para exigir `authenticated` en `SELECT`/`INSERT`. Regenerar `lib/supabase/database.types.ts`. Verificación: una consulta sin JWT falla con "permission denied"; `npm run build` sigue pasando.
3. Crear `app/auth/page.tsx` portando `auth.jsx` con las dos tabs de email/contraseña (sin los botones sociales todavía). Verificación manual: crear una cuenta con un correo real, ver el mensaje de "revisa tu correo", confirmar desde el email recibido, iniciar sesión con ese correo y contraseña, llegar a `/biblioteca`.
4. Añadir los botones "Google"/"GitHub" en `app/auth/page.tsx` y crear `app/auth/callback/route.ts`. Verificación: sin credenciales reales configuradas, el click muestra el error de Supabase ("provider is not enabled") en pantalla sin romper la navegación.
5. Crear `proxy.ts` en la raíz con el refresco de sesión de `@supabase/ssr` y la lista de rutas públicas. Verificación: sin sesión, visitar `/biblioteca`, `/juegos/[id]`, `/juegos/[id]/jugar` y `/salon-de-la-fama` redirige a `/auth`; `/` y `/acerca-de` siguen cargando; `npm run build` pasa.
6. Actualizar `components/Nav.tsx` para leer la sesión (cliente browser) y reaccionar a `onAuthStateChange`. Verificación visual: logueado se ve `{username} ▾`, deslogueado "Iniciar Sesión"; click en `{username} ▾` cierra sesión y vuelve a `/`.
7. Actualizar `app/juegos/[id]/jugar/page.tsx` para prellenar el campo de nombre del modal de fin de partida con `user_metadata.username`. Verificación: jugar una partida logueado, el modal trae el nombre ya escrito y editable.
8. Documentar en `README.md` y `CLAUDE.md`. Verificación: `npm run build` y `npm run lint` pasan sin errores.

---

## Criterios de aceptación

- [ ] Sin sesión, visitar `/biblioteca`, `/juegos/[id]`, `/juegos/[id]/jugar` o `/salon-de-la-fama` redirige a `/auth`.
- [ ] Sin sesión, `/` y `/acerca-de` cargan con normalidad.
- [ ] Crear una cuenta con correo real + usuario + contraseña muestra un mensaje de "revisa tu correo" y no navega a Biblioteca.
- [ ] Tras confirmar el correo e iniciar sesión con ese correo y contraseña, la app navega a `/biblioteca`.
- [ ] Iniciar sesión con credenciales incorrectas muestra un error visible en el formulario sin navegar.
- [ ] Con sesión activa, el nav muestra `{username o correo} ▾` en vez del botón "Iniciar Sesión".
- [ ] Click en el botón de usuario del nav cierra la sesión y redirige a `/`.
- [ ] Con sesión activa, el modal de fin de partida del Reproductor muestra el campo de nombre prellenado con el username de la cuenta, y sigue siendo editable.
- [ ] Los botones "Google" y "GitHub" de `/auth` disparan `signInWithOAuth` (redirige al proveedor, o muestra "provider is not enabled" si no hay credenciales configuradas).
- [ ] Una consulta a `games` o `scores` sin JWT (`anon`) falla con "permission denied"; con un usuario `authenticated` funciona.
- [ ] `npm run build` y `npm run lint` pasan sin errores.

---

## Decisiones

- **Sí:** email/contraseña y OAuth real con Google/GitHub. Decisión explícita del usuario; las credenciales quedan pendientes de configuración manual (ver Riesgos), pero el flujo de código se implementa completo.
- **No:** login por username resuelto a email vía tabla o RPC. Supabase Auth exige email; añadir ese lookup habría requerido una tabla pública adicional solo para esto.
- **Sí:** confirmación de email obligatoria, usando el SMTP de prueba que trae Supabase por defecto. Suficiente para esta etapa del proyecto (sin usuarios reales todavía); se documenta como limitación conocida.
- **No:** SMTP propio. Añade una dependencia externa (proveedor de email) sin necesidad todavía.
- **Sí:** `username` en `user_metadata`, sin tabla `profiles` ni validación de unicidad. Se consideró explícitamente una tabla `profiles` con `username unique` para poder garantizar unicidad, y se descartó para no ampliar el alcance — es coherente con que `scores.name` (SPEC 06) tampoco es único.
- **No:** flujo de "olvidé mi contraseña". Se difiere a un spec futuro para no sumar otra pantalla y otro flujo de email a este spec.
- **Sí:** proteger con `proxy.ts` toda la app salvo Inicio y Acerca de. Es la pieza que SPEC 04 dejó explícitamente pendiente "para el spec de Auth", y la decisión explícita del usuario de eliminar el modo invitado.
- **No:** modo invitado. Se elimina a propósito: jugar y ver el catálogo/leaderboard ahora requieren cuenta.
- **Sí:** nueva migración que restringe a `authenticated` las políticas de RLS de `scores`/`games` de SPEC 06, en vez de editar la migración original. Las migraciones son append-only por convención del proyecto (SPEC 04); las políticas de SPEC 06 quedan obsoletas porque ya no hay tráfico anónimo legítimo contra esas tablas.
- **No:** vincular `scores` a `auth.users` o distinguir "tu mejor marca" en el Salón de la Fama. El nombre del modal solo se prellena desde la cuenta; conectar score↔cuenta de verdad queda para un spec futuro.
- **Sí:** una sola ruta `/auth` con tabs, replicando la estructura del template `auth.jsx`, en vez de dos rutas separadas.
- **Sí:** redirect fijo a `/biblioteca` tras iniciar sesión (no "volver a la página de origen"). Más simple y predecible que propagar un parámetro de retorno por todo el flujo.

---

## Riesgos

| Riesgo                                                                                                   | Mitigación                                                                                                                                      |
| ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| Sin credenciales reales de Google/GitHub, el flujo OAuth no se puede probar de punta a punta en este spec. | Se documenta el error "provider is not enabled" como resultado esperado hasta que se configuren las credenciales manualmente; no bloquea el resto del spec. |
| El SMTP de prueba de Supabase tiene un límite de envíos muy bajo (pocos correos por hora).                 | Documentado como limitación conocida en `README.md`; probar el flujo manualmente con pocas cuentas, no en volumen.                              |
| Un `proxy.ts` mal configurado podría bloquear rutas públicas o dejar pasar rutas que deberían protegerse.  | El paso 5 del plan verifica manualmente cada ruta pública y cada ruta protegida antes de seguir con los pasos siguientes.                        |
| La migración que retira el acceso `anon` a `scores`/`games` podría romper algo si quedara tráfico anónimo. | La app no está en producción todavía; no hay usuarios reales que dependan del acceso anónimo a esas tablas.                                      |

---

## Lo que **no** está en este spec

- "Olvidé mi contraseña" y cualquier flujo de reset.
- Tabla `profiles`, unicidad de username o chequeo de disponibilidad.
- SMTP propio / dominio de email propio.
- Pantalla de "Cuenta" o edición de perfil.
- Vincular `scores` a `auth.users` o destacar "tu mejor marca" en el Salón de la Fama.
- Rate limiting, CAPTCHA o protección anti-bot en el registro.
- Roles o permisos diferenciados entre usuarios.
- Cualquier modo de acceso sin cuenta a Biblioteca, Detalle, Jugar o Salón de la Fama.

Cada uno de estos, si se implementa, va en su propio spec.
