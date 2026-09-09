# Visual QA Report — Frontend Next.js vs Diseño de referencia

Comparación visual real, con capturas de pantalla del navegador embebido de Orca, entre
el frontend Next.js corriendo en `http://localhost:3001` y el diseño de referencia servido
en `http://localhost:8090/` (`Fudo App.dc.html` para vistas mobile, `Fudo Customers.dc.html`
para vistas wide).

## Estado del progreso

- [x] Inicio (`/`) vs vista `home`
- [x] Buscar (`/buscar`) vs vista `list`
- [x] Detalle de restaurante (`/restaurantes/257`) vs vista `detail`
- [x] Regalar (`/regalar`) vs vista `gift`, sin sesión y con sesión (ver sección 4)
- [x] Login (`/login`) y Registro (`/registro`) vs pantalla de login del prototipo (sección 5)
- [x] Perfil (`/perfil`) vs vista `profile` (sección 6)
- [x] QR sheet (Mi QR / Escanear) vs sheet de QR del prototipo (sección 7)
- [x] Fix aplicado y commiteado: botón QR flotante tapaba el ícono "Buscar" cuando no hay
  sesión (ver "Fixes aplicados")
- [x] Fixes aplicados: nav flotante tapaba el final del scroll en Inicio/Buscar/Detalle,
  precio de card partido en 2 líneas en Inicio/Buscar, faltaba ícono de lupa en `/buscar`
  (ver "Fixes aplicados" #2-#4). Verificado con `pnpm lint` / `pnpm build` / `pnpm test`
  (127 tests) y capturas a viewport real 390×844.
- [x] Fix aplicado: header global faltante (logo FUDO + "Activar ubicación") en
  Inicio/Buscar/Detalle, geolocalización real vía `navigator.geolocation`, y distancia real
  (haversine) en vez del "0 km" hardcodeado en las cards (ver "Fixes aplicados" #5).
  Verificado con `pnpm lint` / `pnpm build` / `pnpm test` (127 tests) y DOM/localStorage vía
  `orca eval` (sin captura visual disponible en este entorno — ver la nota de metodología en
  el fix #5).
- [x] Auditoría + fix de los filtros de `/buscar` contra el backend real: `neighborhood` y
  `type` ahora se mandan como query params reales a `GET /api/v1/merchants` (antes se
  filtraban client-side); `dist`/`sort=distancia` ahora calculan la distancia real
  server-side a partir de `?lat=&lng=` (nuevo, sincronizado por `BuscarView` desde
  `use-location.ts`), en vez de comparar contra el `distanceKm: 0` fijo de siempre; `tags`
  ya estaba bien mandado y sigue igual; `price` queda documentado como client-side a
  propósito (el backend filtra por un valor puntual, la UI ofrece bandas — ver "Fixes
  aplicados" #6 para el detalle y el porqué). Verificado con `pnpm lint` / `pnpm build` /
  `pnpm test` (135 tests) y `curl` contra el backend real y contra `/buscar` en modo API real
  (ver "Fixes aplicados" #6 para los comandos y resultados).
- [x] Fix aplicado: pill "Abierto ahora" faltante en el detalle de restaurante (sección 3,
  hallazgo #1) — cálculo real de abierto/cerrado contra `business_hours`, reusando la tabla
  de horarios existente para el chevron en vez de duplicarla (ver "Fixes aplicados" #7).
  Verificado con `pnpm lint` / `pnpm build` / `pnpm test` (144 tests) y datos reales del
  backend corriendo (merchants 257 y 250) vía tests con fixtures reales + `orca eval` en vivo.

### Corrección de metodología (viewport SÍ es controlable)

La sección de arriba dice que no hay forma de forzar 390px de ancho vía CLI. **Eso no es
correcto** — existe el comando `orca viewport --width <w> --height <h> --mobile --page <id>`
(confirmado con `orca agent-context --json`, no está en el texto de ayuda de
`orca skills get orca-cli` pero sí en el schema de comandos). Con él se logró un viewport
real de exactamente 390×844 con `devicePixelRatio: 1`, verificado con
`orca eval --expression "window.innerWidth + 'x' + window.innerHeight"` (devolvió `390x844`
en vez de los 819px del panel). **Ojo con un gotcha real:** el override de viewport se
resetea en cada `orca goto` / navegación — hay que volver a llamar `orca viewport` después
de cada navegación o el ancho vuelve a 819px (con `devicePixelRatio: 2`, lo que además hace
que `orca screenshot` devuelva imágenes a 1638×1364 en vez de 390×844, un buen indicador de
que el override se perdió). Todas las capturas de las secciones 4–7 de abajo están tomadas
a 390×844 real, re-aplicando `orca viewport` después de cada `goto`/`reload`.

## Metodología y limitaciones

- Herramienta: `orca` CLI (tabs propias vía `orca tab create`, `--page <browserPageId>` para
  no chocar con otros agentes trabajando en paralelo).
- **Viewport / mobile**: se investigó control directo de ancho de viewport en el navegador
  embebido de Orca. No existe: `orca goto/screenshot/tab create` no tienen flag de viewport
  ni de device; `orca eval` con `window.resizeTo(390, 844)` no tiene efecto (es una pestaña
  embebida dentro de la app Electron de Orca, no una ventana top-level controlable por
  script); `orca exec --command` no tiene subcomandos `resize`/`viewport`/`set-viewport`/
  `emulate`/`cdp` (solo entendía `device list`, que lista simuladores iOS para el emulator
  bridge, no viewport del browser embebido). Conclusión: **no hay forma de forzar 390px de
  ancho vía CLI**. Se trabajó con el ancho real del panel del navegador embebido de Orca,
  que resultó ser **819px** — por debajo del breakpoint de 900px que el propio proyecto usa
  para diferenciar `Fudo App.dc.html` (mobile, vw<900) de `Fudo Customers.dc.html` (wide,
  vw>=900). Es decir: 819px ya activa el layout mobile de ambos sitios (real y referencia),
  así que la comparación es válida a nivel de estructura/layout mobile aunque no sea
  pixel-perfect a 390px.
- Capturas con `orca screenshot --json` (viewport) decodificadas de base64 a PNG con un
  script Python local (para no volcar el base64 completo en la salida de las tools).
- `orca full-screenshot` no se usó para el diseño de referencia: el canvas de diseño usa
  transforms/zoom internos que hacen que la captura "full page" duplique/distorsione el
  contenido (se ve el mismo frame de teléfono repetido). Se prefirió scroll manual +
  `screenshot` de viewport.

---

## 1. Inicio (`/`) vs vista `home`

Real: `http://localhost:3001/` — Referencia: `Fudo App.dc.html`, tab "Inicio" (ya viene
seleccionado por defecto).

### Coinciden
- Titular "Encontrá dónde comer. **Ganá descuentos** por cada visita." — texto exacto,
  mismo tratamiento (blanco + naranja itálica en "Ganá descuentos").
  fondo dark navy/negro en ambos, acento naranja consistente.
- Buscador con placeholder animado tipo "escribiendo" (real SÍ lo implementa: se vio
  "Parrilla para ir con amigos" con cursor parpadeante — coincide con el comportamiento
  del prototipo de referencia).
- Selector "Cualquiera" (icono storefront + chevron) y botón circular naranja de
  "buscar" (arrow_forward) dentro del buscador — mismo layout.
- Sección "Lugares destacados" con cards horizontales scrolleables: imagen, badge de
  tipo (ícono + label, ej. "Bar"), nombre, barrio, precio "desde $X", distancia.

### Discrepancias reales

1. **[CRÍTICO — RESUELTO, ver "Fixes aplicados" #5] Falta el header completo.** La referencia tiene, arriba del todo: logo
   "FUDO" (wordmark) a la izquierda + botón píldora "Activar ubicación" (ícono
   `location_disabled` + texto) a la derecha. La página real **no tiene ningún header**:
   arranca directo en el titular. Esto no es solo estético — sin el botón de activar
   ubicación no hay forma de que el usuario habilite geolocalización, lo cual explica el
   punto 3.

2. **[MEDIO, corregido tras revisar el snapshot de accesibilidad post-hidratación]
   Bottom nav: 5 ítems en ambos, pero el QR es un FAB elevado en la real vs. un ícono más
   al mismo nivel en la referencia.**
   - Referencia: una sola píldora con **5 ítems al mismo nivel** (sin elevación): Inicio
     (resaltado con fondo naranja + label "Inicio"), search (ícono solo), qr_code_scanner
     (ícono solo), redeem (ícono solo), login (ícono solo, flecha entrando a un recuadro).
   - Real: **también tiene 5 ítems** — Inicio, search, redeem, person (login/cuenta) están
     los 4 como `<Link>` en el nav (confirmado con `orca snapshot` después de esperar
     networkidle; una primera lectura mía, tomada demasiado rápido tras la carga y antes
     de que `PhoneNav` (client component, depende de `useSession`) terminara de
     hidratar/re-renderizar, había mostrado solo 4 y me llevó a reportar por error que
     faltaba el ícono de login — **corregido acá**). La diferencia real que sí queda en
     pie es de tratamiento visual: el botón de QR es un **FAB circular elevado** que
     sobresale por encima de la píldora (`PhoneNav.tsx`, intencional — el comentario del
     componente dice que replica `extendBody: true` del shell de Flutter), mientras que en
     la referencia el ícono de QR está al mismo nivel que el resto, sin elevación. Esto es
     una decisión de diseño ya documentada en el propio código como intencional — no la
     tocamos.

3. **[BUG — RESUELTO, ver "Fixes aplicados" #5] Distancia siempre "0 km".** Todas las cards de "Lugares destacados" muestran
   "0 km" de distancia. Consistente con el punto 1: al no existir el flujo de activar
   ubicación, no hay lat/lng del usuario para calcular distancia real. Es un bug funcional
   encadenado al punto 1, no algo que se arregle solo en el frontend visual.

4. **[BUG visual — ARREGLADO] Precio se rompía en dos líneas y pisaba la distancia.** En
   la card "Bar Santa Fe Alto" (y potencialmente cualquier card con precio de 6+ dígitos
   tipo "$15.500"), el pill "desde $15.500" wrappeaba a 2 líneas ("desde" / "$15.500") y se
   superponía visualmente con el texto "0 km" de al lado. Ver
   `docs/visual-qa-shots/01-inicio-price-wrap-bug-before.png` para la evidencia previa al
   fix. Corregido en `FeaturedGrid.tsx` — ver "Fixes aplicados".

---

## 2. Buscar (`/buscar`) vs vista `list`

Real: `http://localhost:3001/buscar` — Referencia: click en tab "search" del prototipo
`Fudo App.dc.html`.

### Coinciden
- Segmented control "Lugares" / "Platos" con íconos storefront / fork.
- Conteo de resultados ("30 lugares" / "30 lugares encontrados") y datos reales
  coincidentes en las primeras cards (El Rincón de Gorriti, Cervecería Cabrera, Bar Santa
  Fe Alto vienen del mismo seed de merchants — la referencia muestra otros nombres
  mockeados tipo "Don Chile Cantina" porque es contenido de diseño, no back real).
- Botón "Ver mapa" (chip con ícono de mapa) presente en ambos, mismo texto.
- Layout de card: imagen a la izquierda, nombre + tipo/barrio a la derecha, precio en
  pill naranja, distancia con pin. Estructura general de card coincide.

### Discrepancias reales

1. **[MEDIO] Segmented "Lugares/Platos" con tratamiento de color distinto.** Referencia:
   el tab activo ("Lugares") apenas se distingue del inactivo (fondo levemente más claro,
   sin color de marca). Real: el tab activo tiene **relleno naranja sólido** — mucho más
   marcado/prominente que la referencia. Esto puede ser una mejora intencional o una
   desviación — queda documentado, no es un "bug" obvio de implementación sino una
   decisión de estilo a confirmar con diseño.

2. **[FEATURE FALTANTE] Filtros rápidos (chips "Vegano", "Sin TACC", "Picante",
   "Económico") existen en la real y NO están en la referencia** — es al revés de lo
   esperado (la real tiene MÁS que la referencia acá). Vale la pena que el dueño del
   proyecto confirme si es una feature adelantada intencionalmente o contenido de prueba.

3. **[ARREGLADO] Faltaba el ícono de búsqueda (lupa) dentro del input.** Referencia: el
   input de búsqueda tiene un ícono de lupa a la izquierda del placeholder. Real (antes):
   no tenía ícono de lupa, solo el botón circular naranja de submit a la derecha. Corregido
   en `SearchBar.tsx` — ver "Fixes aplicados".

4. **[Corregido tras leer el código — NO es un gap de frontend] "Plato/precio destacado" y
   badge de "premio a las X" en la card.** Referencia: cada card tiene una segunda línea
   "Tacos al pastor · $16.000" (plato insignia + precio) y un badge verde "premio a las X".
   La real no muestra ninguna de las dos cosas en las cards actuales — pero **no es porque
   falte implementar la UI**: `MerchantCard.tsx` ya tiene el JSX condicional para ambas
   (`merchant.topDish` y `merchant.rewardTeaser`, líneas ~98-101 y ~186-193), simplemente
   los merchants que devuelve el backend real (`GET /api/v1/merchants`) no traen esos campos
   poblados todavía. Es un gap de **datos de backend/seed**, no de frontend — documentado
   para que se complete el dato, no para tocar componentes.

6. **[Semántica de precio distinta] El precio principal en la referencia es un valor
   más alto y sin "desde"** (ej. "$42.000" vs. real "desde $14.000"). Puede ser que la
   referencia esté mockeando un "ticket promedio para 2" en vez de "precio por persona
   desde", que es lo que expone el backend real (`price_per_person_min`). Es una decisión
   de producto, no un bug de CSS — queda documentado para que el dueño defina qué dato
   mostrar.

7. **[BUG, mismo root cause que Inicio — RESUELTO, ver "Fixes aplicados" #5] Distancia "0 km" en todas las cards** — mismo
   problema del punto 3 de Inicio (falta activar ubicación).

8. **[BUG — ARREGLADO] Bottom nav flotante tapaba el contenido de la última card visible
   en viewport.** Se veía claramente en la captura (`docs/visual-qa-shots/02-buscar-nav-overlap-bug-before.png`):
   la card "Bar Santa Fe Alto" quedaba parcialmente tapada por la píldora de navegación
   inferior (el precio "$15.500" quedaba debajo del nav), porque `app/buscar/page.tsx` no
   reservaba suficiente `padding-bottom` para compensar el nav `fixed`. Corregido — ver
   "Fixes aplicados".

---

## 3. Detalle de restaurante (`/restaurantes/257`) vs vista `detail`

Real: `http://localhost:3001/restaurantes/257` (El Rincón de Gorriti, id real sacado de
`GET http://localhost:3000/api/v1/merchants`). Referencia: click en la primera card de la
vista `list` del prototipo ("Don Chile Cantina" — contenido mockeado, no es el mismo
restaurante pero la vista es la misma).

### Coinciden (mejor de lo esperado — verificado scrolleando ambas, no solo el primer viewport)
- Hero image de ancho completo, botón "volver" (flecha, círculo oscuro semi-transparente)
  arriba a la izquierda, corazón de favoritos arriba a la derecha.
- Nombre del lugar en heading bold blanco.
- Dirección con ícono de pin.
- Pill de precio naranja "$X – $Y por persona" + distancia con ícono de flecha/pin — mismo
  formato exacto en ambos.
- Botón "WhatsApp" (ícono de chat + label) — presente en ambos.
- Segmented control "Recompensas" / "Menú" debajo de los botones de acción — presente en
  ambos, mismos íconos (medalla / cubiertos).
- Widget "PROGRAMA DE FIDELIZACIÓN — Así funcionan los premios" con anillo de progreso
  "0 VISITAS" y el texto **"Cada visita al local suma. A la 2ª ya tenés premio y a la 10ª
  sos cliente fijo con 5% siempre."** — copy idéntico entre real y referencia, layout
  idéntico. Esto está muy bien implementado.
- Tabla de horarios día por día (Lun–Dom) con formato "18:00–02:00" / "Cerrado" — mismo
  estilo de fila en ambos.
- Real agrega, de forma coherente con el resto de la app, un estado "no logueado" para
  Recompensas (card con candado, "Iniciá sesión para ver tu progreso real..." + botón
  "Iniciar sesión", y un segundo aviso para sumar visitas con QR). La referencia es un
  mock estático y no modela este estado, así que no es una discrepancia — es lógica real
  que el diseño no necesitaba mostrar.

### Discrepancias reales

1. **[FALTA — RESUELTO, ver "Fixes aplicados" #7] Pill "Abierto ahora".** Referencia: entre
   la dirección y el pill de precio hay una píldora completa con ícono de reloj, texto verde
   "Abierto ahora", el horario de hoy ("hoy 12:00 – 00:30") y un chevron para expandir. La
   real no tenía este elemento en absoluto — pasaba directo de la dirección al pill de
   precio. El dato sí existía (la tabla de horarios de abajo lo probaba), pero no había
   resumen de estado "abierto/cerrado ahora" arriba. Corregido con lógica real de negocio
   (compara la hora actual contra `business_hours`, incluyendo horarios que cruzan
   medianoche) — ver "Fixes aplicados" #7 para la implementación y la verificación.

2. **[FALTA] Botón "Delivery".** Referencia: al lado de "WhatsApp" hay un segundo botón
   naranja "Delivery" (ícono de bici). Real: **solo existe el botón "WhatsApp"**, no hay
   ningún botón de delivery. Puede ser intencional (feature de delivery no scopeada para
   el MVP) — documentado para confirmar con producto.

3. **[Diferencia menor de contenido]** Real agrega un ícono de tipo de local (copa/vaso)
   inline antes de "Bar · Palermo", la referencia no tiene ícono ahí (solo texto plano
   "Restaurante · Palermo"). Cosmético, no rompe nada.

4. **[Diferencia de datos, no de código]** Formato de dirección: real usa el nombre
   completo "Ciudad Autónoma de Buenos Aires", la referencia abrevia "CABA". Es dato de
   backend/seed, no una diferencia de implementación de la UI — documentado por si
   conviene truncar/abreviar en el futuro por espacio en pantallas chicas.

5. **[BUG, mismo root cause de siempre — RESUELTO, ver "Fixes aplicados" #5] Distancia "0 km"** en vez de una distancia real
   (ligado a la falta del flujo de activar ubicación en el header — ver hallazgo #1 y #3
   de Inicio).

6. **[BUG — ARREGLADO, mismo bottom nav de siempre]** El nav flotante tapaba el final de la
   tabla de horarios (fila "Dom") y, más abajo, parte del aviso "Iniciá sesión para empezar
   a sumar visitas con el QR del local" (`docs/visual-qa-shots/03-detail-nav-overlap-bug-before.png`).
   Mismo bug de padding que en Inicio y Buscar, corregido en `MerchantDetailView.tsx` — ver
   "Fixes aplicados".

---

## Resumen de hallazgos transversales (aparecen en las 3 páginas)

- **[ARREGLADO] Nav inferior flotante sin padding-bottom de compensación**: en las 3
  páginas (Inicio, Buscar, Detalle), el contenido final del scroll quedaba parcialmente
  tapado por el nav `fixed`. Corregido agregando `padding-bottom` a los 3 contenedores de
  página correspondientes — ver "Fixes aplicados".
- **[RESUELTO] Distancia "0 km" en todos lados** y **[RESUELTO] header global faltante
  (logo FUDO + Activar ubicación)** en las 3 páginas mobile — ver "Fixes aplicados" #5 para
  la implementación (geolocalización real + haversine) y la evidencia.
- El nav inferior sí tiene sus 5 ítems en la real (ver corrección en la sección 1, punto 2)
  — la diferencia real que queda es solo el tratamiento visual del botón de QR (FAB elevado
  vs. ícono plano), documentada como decisión de diseño intencional, no un faltante.

---

## 4. Regalar (`/regalar`) vs vista `gift`

Real: `http://localhost:3001/regalar`, sin sesión y logueado con `info@tomassalina.com` /
`Demo1234`. Referencia: click en tab "redeem" del prototipo (`Fudo App.dc.html`), estado sin
`state.user` y luego con `state.user = "martina"`.

### Sin sesión — coinciden casi exactamente
- Título "Regalar" y bajada "Elegí una gift card de Fudo para usar en cualquier local de la
  red." — texto idéntico.
- Carrusel horizontal de gift cards (CLASSIC $12.000 "Válida en toda la red Fudo", con la
  card GOLD asomando a la derecha como peek de scroll) — mismo layout, mismo gradiente
  naranja en la card CLASSIC.
- Card de bloqueo: ícono de candado (círculo rojo oscuro), "Iniciá sesión para comprar",
  bajada "Podés ver todas las tarjetas y sus beneficios. Para enviar una gift card necesitás
  una cuenta.", botón "Iniciar sesión" — texto y estructura idénticos.

### Con sesión — coinciden casi exactamente (mejor que lo esperado)
- Sección "PARA QUIÉN" con inputs "Teléfono del destinatario" y "Mensaje (opcional)" —
  mismo texto, mismo estilo de input oscuro con borde.
- Botón "Comprar y enviar $12.000" con el mismo efecto de brillo diagonal (glossy highlight)
  que tiene el botón de la referencia — coincide en detalle, no solo en color/texto.

### Discrepancia real (bug, confirmado con evidencia y **ya corregido**, ver "Fixes aplicados")
- El botón QR flotante del nav tapaba casi por completo el ícono "Buscar" cuando no hay
  sesión iniciada (nav asimétrico: 2 ítems a la izquierda, 1 a la derecha porque "Perfil" se
  oculta sin sesión). Confirmado con `getBoundingClientRect()`: el botón QR (60×60,
  `x: 165–225`) se superponía a "Buscar" (`x: 149.5–194.5`) en ~30 de sus 45px de ancho.
  Corregido en `web/components/layout/nav/PhoneNav.tsx` — ver detalle en "Fixes aplicados".

### Discrepancia real (documentada, no tocada — es una decisión de diseño, no un bug de CSS)
- **Estilo del botón QR del nav inferior.** El archivo de referencia real
  (`Fudo App.dc.html`, línea 1036) define el botón QR del nav como
  `background: transparent`, sin gradiente ni sombra — un ícono plano más, del mismo tamaño
  que los demás (`font-size: 21px`). La implementación real usa un botón circular de 60×60
  elevado, con gradiente `cta-from→cta-to` y `shadow-qr` (`0 9px 22px rgba(255,80,35,0.38)`),
  que sobresale por encima de la píldora del nav. El comentario en
  `PhoneNav.tsx` (línea ~36) justifica esto citando el shell de Flutter
  (`_FloatingBottomNav` / `extendBody: true`), no el `.dc.html` de referencia — es decir, es
  una decisión consciente de alinear el nav web con el nav de la app mobile Flutter en vez
  de replicar literalmente el prototipo web. Queda documentado para que el dueño del
  producto confirme si esa es la intención correcta.

---

## 5. Login (`/login`) y Registro (`/registro`)

Real: `http://localhost:3001/login` — Referencia: pantalla de login del prototipo (se llega
haciendo click en el ícono "login" del nav cuando no hay sesión).

### Coinciden
- Logo cuadrado naranja con "F", título "Bienvenido", bajada "Ingresá a tu cuenta de Fudo".
- Inputs "tu@email.com" / "Tu contraseña" (real usa placeholders "Email"/"Contraseña" en el
  `aria-label` pero el placeholder visible coincide).
- Link "¿No tenés cuenta? Registrate" debajo del botón.

### Discrepancia real (feature faltante)
- **Falta el botón "Continuar con Google" y el separador "o con email".** La referencia
  tiene, entre la bajada y los inputs de email/contraseña: un botón secundario "Continuar
  con Google" (fondo `var(--surf)`, borde) y un divisor con texto "o con email". La página
  real pasa directo de la bajada a los inputs — no hay ningún login social ni el separador.
  Esto es una feature de producto (login con Google), no algo que se arregle con CSS —
  queda documentado, no lo tocamos.

### Diferencia menor (probablemente intencional, sistema de diseño)
- El botón "Iniciar sesión" en la referencia es un color sólido flat `#FF5023`, sin sombra.
  El real usa el gradiente `cta-from→cta-to` con `shadow-cta` (glow naranja), igual que el
  resto de los CTAs de la app (mismo tratamiento que en Regalar, Perfil, etc.). Es
  consistencia de design system, no un error — de hecho el real es más consistente
  internamente que el prototipo, que trata este botón puntual distinto al resto de sus
  propios CTAs (compará con `tabBits` del nav, que sí usa el gradiente + sombra).

### Registro (`/registro`)
No existe una vista de registro dedicada en el prototipo — el link "Registrate" del
`.dc.html` llama al mismo handler `login` (fake-login directo, sin formulario). No hay
entonces una referencia 1:1 contra la cual comparar pixel por pixel. La página real
(`Creá tu cuenta`, campos Nombre/Apellido/Email/Teléfono/Contraseña) es consistente en
estilo con `/login` (mismo logo, misma tipografía de heading, mismo tratamiento de inputs y
botón CTA) — buena señal de coherencia interna aunque no haya diseño de referencia que la
respalde directamente.

---

## 6. Perfil (`/perfil`) vs vista `profile`

Real: `http://localhost:3001/perfil`, logueado con `info@tomassalina.com`. Referencia: tab
"person"/"Perfil" del prototipo con `state.user = "martina"` (datos mockeados: "Martina
Giménez").

### Coinciden
- Avatar circular con iniciales + nombre + email en la fila superior.
- Badge de tier ("Plata") con el mismo pill naranja/rojo translúcido.
- Sección "LUGARES QUE VISITASTE" con cards: imagen a la izquierda, nombre, "X visitas ·
  última hace N días", badge de tier a la derecha — estructura de card idéntica.

### Discrepancias reales

1. **[FALTA] Segmented control "Visitas / Favoritos / Ajustes".** La referencia tiene, debajo
   del header con nombre/email, una píldora con 3 tabs (`history` Visitas, `favorite_border`
   Favoritos, `settings` Ajustes) — "Visitas" viene seleccionado con fondo resaltado. La
   página real **no tiene este selector de tabs en absoluto**: va directo del header a la
   lista "LUGARES QUE VISITASTE", como si solo existiera el contenido de la pestaña
   "Visitas". No hay forma de llegar a "Favoritos" ni "Ajustes" desde acá.

2. **[FALTA] Barra de progreso por lugar (puntitos de visitas).** En la referencia, cada
   card de "lugares que visitaste" tiene, debajo del texto "X visitas · última hace N días",
   una fila de círculos pequeños (naranjas = visitas hechas, grises = visitas que faltan
   para el premio) — un progreso visual por local. La real no tiene esos puntitos, solo el
   texto y el badge de tier.

3. **[Posición distinta] Badge de tier ("Plata").** Referencia: al mismo nivel que el nombre
   y el email, alineado arriba a la derecha del header. Real: en una fila propia, debajo del
   bloque nombre/email, alineado a la izquierda. Cambio de layout menor pero visible.

4. **[Corregido tras revisar el código fuente del prototipo — NO es contenido extra]**
   Primera lectura mía (solo mirando la vista por defecto "Visitas") decía que la card con
   "DNI: Pendiente", "Teléfono: Sin cargar" y el botón "Actualizar mis datos" era contenido
   inventado, sin equivalente en el prototipo. Es **incorrecto** — al leer el HTML fuente de
   `Fudo App.dc.html` (`dataRows`, línea ~1897 y el sheet `editOpen`, línea ~883) esos campos
   sí existen: la referencia tiene un tab **"Ajustes"** (el 3ro del segmented control del
   punto 1, con ícono `settings`) que lista `Nombre`, `Email`, `Teléfono`, `DNI` (enmascarado
   `•••• 4821`) y `Alta`, cada uno con un chevron que abre un bottom sheet **"Actualizar mis
   datos"** (título Barlow 800 19px) con inputs Nombre/Apellido/Email/Teléfono y botón
   "Guardar cambios" — literalmente el mismo botón/flujo que el real. El tab "Ajustes"
   también tiene toggles de Tema claro/oscuro, Notificaciones y Alertas de precio, más
   "Enviar link" (reset de contraseña) y "Eliminar mi cuenta", **ninguno de los cuales existe
   en la real**. Conclusión correcta: la página real no agrega contenido inventado — lo que
   hace es **aplanar** una porción chica de lo que en la referencia vive detrás del tab
   Ajustes (solo DNI + Teléfono + acceso a "Actualizar mis datos") directo en la pantalla
   principal, sin el resto de Ajustes (Nombre/Email/Alta como filas, toggles de tema/
   notificaciones/alertas, reset de contraseña, eliminar cuenta) y sin el tab switcher que
   los contendría. Esto es consistente con el punto 1 (falta el segmented control) — son la
   misma causa raíz, no dos hallazgos independientes.

Ninguno de estos puntos es un fix de "bajo riesgo" (todos requieren agregar estado/lógica
nueva, no solo CSS) — quedaron documentados para decisión de producto/diseño. **Estado
actual: los 4 hallazgos de arriba están resueltos**, ver el detalle punto por punto abajo.

### Hallazgos #1-#4 — RESUELTOS

**Archivos nuevos:** `web/components/ui/SegmentedControl.tsx` (segmented control genérico,
primera extracción del patrón — ver su comentario de cabecera para por qué no se tocó
`ResultModeToggle.tsx` ni el switcher hecho a mano de `QrSheetContent.tsx`, los otros dos
lugares que ya repetían este patrón), `web/lib/favorites/favorites-store.ts` (favoritos
client-side), `web/components/features/perfil/FavoritesTab.tsx`,
`web/components/features/perfil/SettingsTab.tsx`. **Modificados:**
`web/components/features/perfil/PerfilView.tsx` (agrega el estado de tab + arma las 3
tabpanels), `web/components/features/perfil/ProfileHeader.tsx` (recorta a
avatar/nombre/email/tier — DNI/Teléfono/"Actualizar mis datos" se mudaron a Ajustes),
`web/components/features/perfil/VisitHistoryList.tsx` (color de los puntitos),
`web/components/features/buscar/FavoriteButton.tsx` (pasa a estado compartido, ver hallazgo
#3 de abajo), `web/lib/session/session-provider.tsx` (agrega `createdAt` para la fila
"Alta"). **Tests:** `__tests__/app/perfil/page.test.tsx` reescrito para navegar por tabs,
`__tests__/lib/favorites/favorites-store.test.ts` y
`__tests__/components/features/perfil/FavoritesTab.test.tsx` nuevos — 144 tests en verde
(vs. 127 antes), `pnpm lint` y `pnpm build` (41 páginas) también limpios.

1. **Segmented control "Visitas/Favoritos/Ajustes" — implementado.** Verificado real en el
   browser (`orca`, sesión con `info@tomassalina.com`/`Demo1234`, viewport 390×844): las 3
   tabs existen (`role="tablist"`/`"tab"`), cambian el panel visible al hacer click, y el
   tratamiento visual es el del pill naranja de `ResultModeToggle` ("Lugares/Platos" en
   Buscar) tal como pidió la tarea — **no** el `var(--surf2)` sutil que usa el `.dc.html` de
   referencia para este mismo control, una diferencia de estilo ya aceptada en el resto de
   la app (ver hallazgo #1 de la sección 2, mismo criterio). **Nota de layout no pedida
   explícitamente pero relevante:** la referencia wide (`Fudo Customers.dc.html`, ~línea
   805) muestra este mismo `pTabs` como una nav vertical dentro de un sidebar sticky, un
   layout de 2 columnas distinto del de phone. No se reprodujo esa variante — Perfil ahora
   es una sola columna centrada (`max-w-[620px]`) en cualquier viewport, igual que
   `/regalar`. Documentado como simplificación deliberada, no como gap sin resolver.

2. **Puntitos de progreso por visita — ya existían en el código, con el color equivocado;
   corregido.** Verificación importante antes de asumir el hallazgo original: `VisitStamps`
   (dentro de `VisitHistoryList.tsx`) **ya estaba implementado y wireado** desde el commit
   `bff9bad` (anterior a este QA), no faltaba como decía el hallazgo #2 original — se
   confirmó leyendo `lib/mock/loyalty.ts` (el conteo mock de visitas nunca supera 8, así que
   `nextStep` siempre existe) y con `orca eval` en vivo (`getComputedStyle` sobre los puntos
   de "Tostado Café Club": 6 rellenos + 2 vacíos, un `Consumer` con 6 visitas mock). Lo que sí
   era un bug real: los puntos rellenos usaban `bg-success` (verde, `#8FD46A`) en vez de
   naranja — la referencia solo llama a `this.stamps()` una vez en todo el archivo, para esta
   lista exacta, y pasa explícitamente `"#FF5023"` (naranja), no el verde que `stamps()` usa
   de default en otros lados. Corregido a `bg-accent`; confirmado en vivo que los puntos
   rellenos computan a `rgb(255, 80, 35)`.

3. **Badge de tier reposicionado — hecho.** `ProfileHeader.tsx` ahora pone `topTier` como
   último hijo del `flex` que ya contiene avatar + nombre/email, igual que
   `docs/design-reference/Fudo App.dc.html` línea ~684. Confirmado en el snapshot de
   accesibilidad en vivo: "Plata" aparece inmediatamente después de "info@tomassalina.com" y
   antes del `tablist`, no en una fila propia.

4. **Tab "Ajustes" — implementado con el contenido real de `dataRows`/`prefRows`, con una
   corrección al brief de esta tarea.** El brief de esta tarea (arriba) decía "cada [fila]
   con chevron que abre el sheet 'Actualizar mis datos'" — **eso no es lo que dice el HTML
   fuente que la misma tarea pidió revisar**: en `Fudo App.dc.html` (líneas 751-762),
   `dataRows` (Nombre/Email/Teléfono/DNI/Alta) se renderiza como 5 filas de solo lectura, sin
   `onClick` ni chevron individual — el chevron y el `onClick={openEdit}` están **únicamente**
   en el botón separado "Actualizar mis datos" debajo de la lista. Implementado así (matching
   la fuente, no la descripción del brief): `SettingsTab.tsx` renderiza los 5 `dataRows`
   estáticos + un botón "Actualizar mis datos" aparte que abre el mismo `EditProfileForm` que
   ya existía (reusado, no duplicado). Verificado en vivo: click en "Actualizar mis datos" en
   el tab Ajustes abre el sheet.

   **Qué quedó conectado a backend real vs. qué es UI-only (honesto, no todo es igual):**
   - **Real:** Nombre/Email/Teléfono/DNI/Alta leen `useSession().consumer` (sesión mockeada
     pero real dentro de esa mock); "Actualizar mis datos" llama a `updateProfile()` real;
     "Cerrar sesión" llama a `logout()` real (se reubicó desde fuera de las tabs a "SEGURIDAD
     Y CUENTA", como en el diseño).
   - **UI-only, documentado en el propio código (`SettingsTab.tsx`, comentario de cabecera):**
     toggles de "Notificaciones" y "Alertas de precio" (estado local, se resetea al recargar).
     Verificado además que el backend **sí** expone un recurso real de settings por consumer
     (`ConsumerSetting` — campos `theme`/`notifications_enabled`,
     `backend/app/controllers/api/v1/consumer_settings_controller.rb`, confirmado leyendo el
     controller) — pero llegar a él requiere un request autenticado, y **esta app web no tiene
     ningún mecanismo de auth real todavía**: la sesión es 100% mock/localStorage
     (`lib/session/session-provider.tsx`, sin ningún `fetch`/token) y `apiFetch`
     (`lib/api/client.ts`) no adjunta ningún header de auth. Conectarlo de verdad implica
     construir auth real en toda la app — fuera de alcance de "completar Perfil". El toggle
     de "Tema claro/oscuro" del diseño **no se reprodujo**: esta app no tiene tema claro (solo
     define paleta dark en `globals.css`), un toggle sin nada que alternar sería peor que no
     tenerlo.
   - **UI-only con confirmación pero sin acción real, documentado:** "Enviar link" (reset de
     contraseña) y "Eliminar mi cuenta". Confirmado leyendo `backend/config/routes.rb`: no
     existe ninguna ruta de reset de contraseña ni de borrado de cuenta — no es un problema de
     auth como los toggles, directamente no existe el endpoint. "Eliminar mi cuenta" pide
     confirmación en 2 pasos (como el diseño) pero el segundo tap muestra explícitamente
     "Pendiente de backend — tu cuenta no fue eliminada" en vez de simular un borrado real
     (el propio mock del diseño hace `logout()` en ese punto, lo cual acá se consideró
     engañoso — un consumer pensaría que su cuenta se borró de verdad).
   - **Chip "DNI · Verificado y cifrado":** solo se muestra así cuando `consumer.dni` existe
     de verdad (nunca, en este mock — nada en el flujo de login/registro colecta DNI); si no,
     muestra "Pendiente", en vez de afirmar "verificado" incondicionalmente como hace el mock
     estático de la referencia.

### Tab "Favoritos" — implementado, con una aclaración importante sobre qué es real

La tarea pedía confirmar si `GET /api/v1/favorites` existe antes de asumir. **Se confirmó
que sí existe** (`backend/app/controllers/api/v1/favorites_controller.rb`: `index`/`create`/
`destroy`, scoped a `current_consumer`, con manejo de unique-index en soft-delete). **Pero no
se llama desde acá** — mismo motivo que los toggles del punto 4: no hay ningún token de auth
real que este front pueda adjuntar a ese request (confirmado que `lib/session/
session-provider.tsx` no hace ningún `fetch` y `apiFetch` no soporta headers de auth), así
que pegarle a ese endpoint devolvería 401 siempre, con o sin sesión mock activa.

En vez de dejar la tab permanentemente vacía, se armó `lib/favorites/favorites-store.ts`: un
store client-side (mismo patrón `useSyncExternalStore` + `localStorage` que
`lib/location/use-location.ts`) que guarda qué `merchantId`s se marcaron como favoritos.
Esto además corrigió un bug preexistente de paso: `FavoriteButton.tsx` (el corazón de las
cards/detalle) tenía `useState` **local e independiente por instancia** — favoritear un lugar
en `/buscar` no se reflejaba en el mismo lugar visto en `/restaurantes/:id`, y se perdía al
recargar. Ahora usa el store compartido, así que favoritear en cualquier lado es consistente
y aparece en Perfil → Favoritos. El nombre/foto/tipo de cada merchant favorito sí se resuelve
con datos reales vía `getMerchantById` (mock o backend real, según `isApiConfigured()`) — lo
que **no** es real es el flag de "favorito" en sí, que vive solo en ese navegador, no en la
tabla `favorites` del backend. Verificado en vivo con `orca`: favoritear "El Rincón de
Gorriti" desde `/restaurantes/257` (persistido en `localStorage['fudo:favorite-merchant-ids']
= [257]`) lo hizo aparecer en Perfil → Favoritos con nombre real "El Rincón de Gorriti" y meta
"Bar · Palermo"; sin favoritos, se ve el estado vacío del diseño ("Marcá lugares con el
corazón y aparecen acá.").

### Hallazgo nuevo, descubierto durante esta verificación (no introducido por este cambio, no arreglado)

**Un hard-reload de `/perfil` con sesión mock válida redirige a `/login` en vez de mostrar el
perfil.** Reproducido de forma consistente con `orca goto` (navegación de página completa, no
un `<Link>` del lado del cliente) apuntando a `/perfil` con
`localStorage['fudo:consumer-session']` ya seteado: la página siempre rebota a `/login`, a
pesar de que el dato de sesión está ahí (confirmado leyendo `localStorage` después del
rebote). Causa probable: `useSyncExternalStore` en `session-provider.tsx` usa
`getServerSnapshot` (`null`) para el render de SSR/primera pintada; el `useEffect` de
redirect en `PerfilView.tsx` corre con ese `null` antes de que React corrija el snapshot al
valor real de `localStorage`, y el `router.replace("/login")` ya se disparó para cuando se
corrige. **Confirmado que no lo causó este cambio:** el `diff` de
`lib/session/session-provider.tsx` en este commit solo agrega el campo opcional `createdAt` —
no se tocó `getSnapshot`/`getServerSnapshot` ni el efecto de redirect de `PerfilView.tsx`
(ambos ya tenían esta forma exacta antes de este trabajo). Navegar a `/perfil` con un
`<Link>` del lado del cliente (el flujo real: login → redirect interno, o click en el ícono
"Perfil" del nav) no dispara el bug — solo una recarga completa de esa URL puntual. Queda
documentado, no arreglado: es un bug de la infraestructura de sesión mockeada, no del
contenido de Perfil que pedía esta tarea, y tocar `session-provider.tsx` más allá de lo
mínimo tenía riesgo de pisar trabajo concurrente de otro agente en este mismo working
directory (ver `git status` al momento de este commit — hay cambios sin commitear ajenos en
`lib/api/`, `lib/data/search.ts`, `lib/utils/{buscar-href,distance}.ts`, `components/features/
buscar/`, no tocados por este trabajo).

---

## 7. QR sheet (Mi QR / Escanear)

Real: se abre desde el botón QR del nav estando logueado (`/perfil` → botón "Mi código QR").
Referencia: `openQr` en el prototipo, mismo botón del nav, con `state.user` seteado.

### Coinciden — fidelidad casi pixel-perfect en ambas tabs
- Sheet con drag handle arriba, título "Tu código Fudo", botón de cierre (X) a la derecha.
- Segmented control "Mi QR" / "Escanear" con los mismos íconos, mismo estilo de píldora.
- **Tab "Escanear":** marco de escaneo con las 4 esquinas naranjas, línea de escaneo
  animada, fondo con líneas diagonales repetidas, título "Escaneá el QR del local" y bajada
  "Se suma la visita y aplicamos tu descuento al instante." — texto idéntico, layout
  idéntico.
- **Tab "Mi QR":** QR code en card blanca redondeada, nombre del usuario debajo, bajada
  "Mostrale este código al mesero para validar tu visita." (texto idéntico), pill inferior
  con ícono + "ID FD-XXXX-XXXX".
- El backdrop (contenido de la página detrás, dimmed/blurred) también coincide en
  tratamiento visual.

No se encontraron discrepancias reales en este componente — es la vista con mejor fidelidad
de todas las revisadas hasta ahora.

---

## Fixes aplicados

### 1. Botón QR flotante tapaba el ícono "Buscar" del nav (logueado afuera)

**Archivo:** `web/components/layout/nav/PhoneNav.tsx`. **Commit:**
`fix(web): center floating QR nav button on its own spacer`.

**Causa raíz:** el botón QR se centraba con `absolute left-1/2 -translate-x-1/2` respecto a
**toda la píldora del nav** (que contiene `NAV_LEFT` + spacer + `navRight`). Esa cuenta solo
da un centro correcto cuando `NAV_LEFT` y `navRight` tienen la misma cantidad de ítems. Sin
sesión, `navRight` filtra "Perfil" (ver `visibleNavRight` en `nav-items.ts`) y queda con 2
ítems a la izquierda (Inicio, Buscar) contra 1 a la derecha (Regalar) — el punto medio real
de la píldora se corre hacia la izquierda, y el botón absolutamente centrado termina
tapando el ícono "Buscar" en vez de caer sobre el spacer reservado.

**Fix:** en vez de centrar el botón respecto a toda la píldora, se lo movió adentro del
propio `<span>` reservado (`w-11`) y se lo centra respecto a ese span. Así el centrado sigue
la posición real del hueco reservado sin importar cuántos ítems haya de cada lado.

**Verificación:**
- Antes del fix (sin sesión): QR en `x: 165–225` vs. Buscar en `x: 149.5–194.5` — solapamiento
  de ~30px de los 45px del ícono (prácticamente lo tapaba entero).
- Después del fix (sin sesión): QR en `x: 188.5–248.5` vs. Buscar en `x: 149.5–194.5` —
  solapamiento de ~6px, en el padding del botón, no sobre el glifo visible.
- Verificado también con sesión iniciada (nav simétrico, 2 y 2 ítems): solapamiento de ~6px
  parejo a ambos lados (Buscar y Regalar), consistente con el overlap intencional del botón
  elevado sobre sus vecinos que ya documentaba el comentario original del código.
- `pnpm lint`, `pnpm build` y `pnpm test` (127 tests, 20 archivos) corren limpios después
  del cambio.
- Capturas antes/después en
  `/private/tmp/claude-501/-Users-salina-dev-web2-fudo/03d738ea-da9a-407a-abe3-8b22e151b3fa/scratchpad/shots/live_login_mobile.png`
  (antes) y `live_login_mobile_fixed.png` (después).

### 2. Nav flotante tapaba el final del contenido scrolleable (Inicio, Buscar, Detalle)

**Archivos:** `web/app/(marketing)/page.tsx`, `web/app/buscar/page.tsx`,
`web/components/features/restaurantes/MerchantDetailView.tsx`.

**Causa raíz:** `PhoneNav` (`web/components/layout/nav/PhoneNav.tsx`) es `fixed inset-x-0
bottom-6`, así que no reserva espacio en el flujo del documento (es intencional — el propio
comentario del componente dice que imita `extendBody: true` del shell de Flutter). Su
alcance real desde el borde inferior del viewport es de unos **~80px** (`bottom-6` = 24px +
píldora de ~56px de alto, sin contar que el botón de QR sobresale aún más arriba). Las 3
páginas reservaban menos que eso al final de su contenido:
- `app/(marketing)/page.tsx` (Inicio): `pb-16` = 64px.
- `app/buscar/page.tsx`: `py-8` = 32px arriba **y** abajo (bottom insuficiente).
- `MerchantDetailView.tsx`, rama phone (`isPhone`): `pb-16` = 64px.

**Fix:** se subió el padding-bottom de las 3 a `pb-28` (112px, > 80px de margen real), y en
`buscar/page.tsx` se separó `py-8` en `pt-8 pb-28` para no tocar el padding superior. Se optó
por bumpear el valor compartido en vez de condicionarlo a `useIsPhoneViewport()` (que hubiera
requerido convertir `app/(marketing)/page.tsx` y `app/buscar/page.tsx` — ambos Server
Components — en Client Components solo para este ajuste): en la rama wide (`vw>=900`) el nav
inferior flotante no existe (usa `WideNav`, sticky-top), así que el único efecto colateral es
un poco más de aire al final de esas 2 páginas en desktop — cosmético, no un bug.

**Verificación:**
- `orca eval` confirmó `padding-bottom: 112px` computado en los 3 contenedores después del
  cambio (`main` de `/buscar`, `section` de `/`, y el wrapper phone de
  `MerchantDetailView.tsx`).
- Capturas a viewport real de 390×844 (`orca viewport --width 390 --height 844 --mobile`)
  confirmando que la última card de "Lugares destacados" en Inicio ya no queda tapada por
  el nav: `/private/tmp/claude-501/-Users-salina-dev-web2-fudo/03d738ea-da9a-407a-abe3-8b22e151b3fa/scratchpad/shots/inicio_fix_390.png`.
- `pnpm lint`, `pnpm build` (41 páginas generadas sin error) y `pnpm test` (127 tests, 20
  archivos) corren limpios después del cambio.

### 3. Precio se rompía en dos líneas y pisaba la distancia (Inicio y Buscar)

**Archivos:** `web/components/features/home/FeaturedGrid.tsx`,
`web/components/features/buscar/MerchantCard.tsx`.

**Causa raíz:** el `<span>` del pill de precio ("desde $X") y el `<span>` de distancia
("0 km") no tenían `whitespace-nowrap` ni `flex-shrink: 0`. En las cards angostas del
carrusel de Inicio (`w-[220px]`), un precio de 6 dígitos como "$15.500" alcanzaba a
wrappear su propio texto en 2 líneas dentro del pill, empujándose visualmente sobre el
`<span>` de distancia de al lado.

**Fix:** se agregó `whitespace-nowrap` + `flex-none` a ambos spans (precio y distancia) en
los 3 lugares donde se repite este patrón (`FeaturedGrid.tsx` y las 2 variantes de card de
`MerchantCard.tsx`, layout "row" y "card"). Cambio puramente defensivo de clases Tailwind,
sin tocar lógica.

**Verificación:** captura a 390×844 real de Inicio scrolleado
(`/private/tmp/claude-501/-Users-salina-dev-web2-fudo/03d738ea-da9a-407a-abe3-8b22e151b3fa/scratchpad/shots/inicio_fix_390.png`)
muestra "desde $14.000" y "desde $16.000" en una sola línea, sin superposición con "0 km".
`pnpm lint`/`build`/`test` limpios (mismo run que el fix anterior).

### 4. Faltaba el ícono de lupa en el buscador de `/buscar`

**Archivo:** `web/components/features/buscar/SearchBar.tsx`.

**Fix:** se agregó un `<span>` con el ícono `search` (Material Symbols) antes del `<input>`,
mismo tratamiento visual (`text-foreground-faint`) que el resto de los íconos secundarios de
la app. Cambio de una sola línea de JSX, sin lógica nueva.

**Verificación:** captura en vivo confirmando el ícono de lupa a la izquierda del
placeholder, layout intacto (el botón de submit naranja no se movió):
`/private/tmp/claude-501/-Users-salina-dev-web2-fudo/03d738ea-da9a-407a-abe3-8b22e151b3fa/scratchpad/shots/buscar_fix_check.png`.
`pnpm lint`/`build`/`test` limpios.

### 5. Header global faltante (logo FUDO + "Activar ubicación") + distancia "0 km" — RESUELTO

**Archivos nuevos:** `web/lib/location/use-location.ts` (hook de geolocalización real,
persistido en `localStorage`), `web/lib/location/use-merchant-distance.ts` (distancia real
por merchant), `web/lib/utils/distance.ts` (haversine compartido, extraído de
`lib/mock/merchants.ts` para no reinventarlo), `web/components/layout/LocationButton.tsx`
(pill compartida), `web/components/layout/Header.tsx` (header phone-only, logo + pill).
**Archivos modificados:** `web/components/layout/nav/WideNav.tsx` (agrega la misma pill al
nav sticky de wide, que en la referencia también la tiene —
`docs/design-reference/Fudo Customers.dc.html` línea ~173), `web/lib/mock/merchants.ts`
(deja de duplicar el haversine), `web/components/features/home/FeaturedGrid.tsx`,
`web/components/features/buscar/MerchantCard.tsx`, `web/components/features/buscar/DishCard.tsx`,
`web/components/features/restaurantes/MerchantDetailView.tsx` (usan la distancia real cuando
hay ubicación activa, con fallback al `merchant.distanceKm` existente — sigue en "0 km" para
datos reales hasta que el usuario activa ubicación, que es el comportamiento esperado, no un
bug residual), y las 3 páginas mobile (`app/(marketing)/page.tsx`, `app/buscar/page.tsx`,
`app/restaurantes/[id]/page.tsx` — solo import + render de `<Header />`, sin tocar el resto).

**Causa raíz (hallazgo #1 de Inicio):** no existía ningún componente de header en la
implementación real — arrancaba directo en el titular. Sin un botón "Activar ubicación" no
había forma de que el browser pidiera geolocalización, así que `distanceKm` quedaba siempre
en el `0` por defecto que pone `parseMerchant` (`lib/api/merchants.ts`) para datos reales.

**Fix:** `Header` (phone, `vw<900`) y la pill agregada a `WideNav` (`vw>=900`) llaman a
`navigator.geolocation.getCurrentPosition` vía `useLocation()`, un hook de external-store
(mismo patrón que `lib/session/session-provider.tsx`) que persiste `{latitude, longitude}`
en `localStorage` bajo la key `fudo:user-location` y no vuelve a pedir permiso en cada
recarga. Un click estando activo limpia la ubicación (`clearLocation`) y el botón vuelve a
"Activar ubicación"; un permiso denegado o no soportado también cae con gracia al mismo
estado "off" — nunca rompe la UI. `useMerchantDistanceKm` calcula la distancia real
(haversine) entre esas coordenadas y cada merchant, y las 4 cards (`FeaturedGrid`,
`MerchantCard` en sus 2 layouts, `DishCard`, `MerchantDetailView`) la muestran en vez del
campo `distanceKm` pre-cargado cuando hay ubicación activa.

**Verificación real (sin captura visual disponible — ver nota de metodología):**
- DOM: `document.querySelector('img[alt="Fudo"]')` y el botón "Activar ubicación" (ícono
  `location_disabled`) confirmados presentes en `/`, `/buscar` y `/restaurantes/257` a
  390×844 real, y ausentes duplicados en wide (1280×900, donde solo aparece el logo/pill de
  `WideNav`, no un segundo header).
- Antes de activar ubicación: las 5 primeras cards de Inicio mostraban `"0 km"` — reproduce
  el bug reportado.
- Geolocalización mockeada vía `orca eval` (`navigator.geolocation.getCurrentPosition`
  parcheado para devolver `{latitude: -34.6037, longitude: -58.3816}`) + click real en el
  botón: el ícono cambió a `my_location`, el label a "Ubicación activada",
  `localStorage.getItem('fudo:user-location')` devolvió las coordenadas, y las mismas 5
  cards pasaron a mostrar distancias reales (`4,8 km`, `3,1 km`, `6,3 km`, `7,4 km`,
  `5,6 km`) — verificado en Inicio, Buscar y Detalle, y persistente entre navegaciones
  (sin volver a pedir permiso).
- Caso de permiso denegado: `getCurrentPosition` mockeado para invocar el callback de error;
  tras el click el botón volvió solo a `location_disabled` / "Activar ubicación",
  `localStorage` quedó sin la key, y `document.body` siguió intacto (sin excepciones ni UI
  rota).
- `pnpm lint`, `pnpm build` (41 páginas, sin errores de TypeScript) y `pnpm test` (127 tests,
  20 archivos) corren limpios.
- **Limitación de metodología:** a diferencia de fixes anteriores, no se pudo tomar captura
  de pantalla esta vez (`orca screenshot` devolvió `"Screenshot timed out — the browser tab
  may not be visible or the window may not have focus"` de forma consistente en este entorno,
  incluso reaplicando el viewport). La verificación de arriba se hizo 100% vía DOM/localStorage
  con `orca eval`, que es más preciso que una inspección visual para confirmar valores exactos
  (texto del botón, ícono, coordenadas persistidas, km calculados) aunque no reemplaza una
  captura para fidelidad pixel-a-pixel del layout.

### 6. Filtros de `/buscar` contra el backend real (`neighborhood`, `type`, distancia) — RESUELTO

**Auditoría inicial (`Api::V1::MerchantsController#filtered_merchants` +
`Merchant.search`, backend/app/controllers/api/v1/merchants_controller.rb):** los únicos
query params reales que `GET /api/v1/merchants` soporta son `neighborhood` (match exacto),
`type` (match exacto contra el enum), `tags` (CSV, case-insensitive) y `price_per_person`
(un único valor: `price_per_person_min <= valor AND price_per_person_max >= valor`) — no
existe ningún param de lat/lng ni de distancia en el backend.

| Filtro | Estado antes | Estado después |
|---|---|---|
| `tags` (chips IA) | Ya mandaba `?tags=` real (`lib/api/merchants.ts`) | Sin cambios — ya estaba bien |
| `type` | Filtrado 100% client-side sobre la lista completa (`lib/mock/search.ts`) | Mandado como `?type=` real; el filtro client-side queda como no-op redundante (ver detalle) |
| `neighborhood` (hood) | Filtrado 100% client-side (`applyExtraFilters` en `page.tsx`), pese a que el backend sí lo soporta | Mandado como `?neighborhood=` real cuando el filtro está activo |
| `dist` / `sort=distancia` | Comparaba contra `distanceKm: 0` fijo (el Server Component no tiene la posición del visitante) | `distanceKm` real calculado server-side (haversine) a partir de `?lat=&lng=`, sincronizado por `BuscarView` desde `use-location.ts` |
| `price` (banda) | Filtrado 100% client-side | **Sin cambios, a propósito** — ver justificación abajo |

**Archivos modificados:**
- `web/lib/api/merchants.ts` — `MerchantsListFilters` ahora acepta `type`/`neighborhood`,
  forwardeados como query params reales en `fetchMerchants`.
- `web/lib/data/search.ts` — `searchMerchants` pasa `type`/`neighborhood` al fetch real en
  vez de filtrar `type` únicamente client-side después.
- `web/lib/mock/search.ts` — `SearchFilters` acepta (e ignora) `neighborhood`, para que un
  mismo objeto de filtros sirva a ambos modos (mock/real) sin ramificar la firma.
- `web/app/buscar/page.tsx` — hace un segundo fetch con `neighborhood` **solo** cuando el
  filtro de barrio está activo (para no perder la lista completa de barrios que alimenta el
  `<select>`, que necesita el universo *sin* filtrar por barrio); agrega `withDistances()`
  (haversine, mismo helper que ya usaba el cliente) para calcular `distanceKm` real a partir
  de `?lat=&lng=` antes de aplicar `dist`/`sort=distancia`.
- `web/lib/utils/distance.ts` — se le agregó `roundToOneDecimal` (estaba duplicado en
  `use-merchant-distance.ts`) para que el redondeo sea el mismo tanto si la distancia se
  calculó en el servidor (nuevo) como en el cliente (ya existente).
- `web/lib/location/use-merchant-distance.ts` — importa `roundToOneDecimal` compartido en
  vez de su copia local.
- `web/lib/utils/buscar-href.ts` — agrega `lat`/`lng` a `BuscarParams` (excluidos de
  `countActiveFilters`: son posición sincronizada automáticamente, no un filtro que el
  visitante elige).
- `web/components/features/buscar/BuscarView.tsx` — nuevo efecto que sincroniza
  `useLocation()` a `?lat=&lng=` vía `router.replace` (sin agregar entradas al historial),
  redondeando a 3 decimales (~110m) antes de ponerlo en la URL.
- `web/__tests__/lib/utils/buscar-href.test.ts` — casos nuevos para `lat`/`lng` (orden de
  campos, limpieza con override `null`, exclusión de `countActiveFilters`).

**Decisión de diseño — por qué `price` queda client-side a propósito:** el backend filtra
`price_per_person` como *"¿este único valor cae dentro del rango [min, max] del merchant?"*
(pensado para "quiero gastar ~$X"), pero la UI de `/buscar` ofrece **bandas** ("Hasta
$20.000", "$20.000–$40.000", "Más de $40.000"). Forzar un valor representativo de la banda
al contrato de "punto único" del backend cambiaría en silencio qué significa "Hasta
$20.000" para el usuario (¿el mínimo de la banda? ¿el máximo? ninguno es fiel a la intención
real de "un lugar que entre en este presupuesto"). Como el filtro sigue operando sobre datos
reales ya traídos del backend (no mock), mantenerlo client-side no es una regresión
funcional — es evitar traducir mal un contrato que no calza 1:1. Documentado acá en vez de
forzar una traducción incorrecta.

**Decisión de diseño — por qué `lat`/`lng` en la URL en vez de otro mecanismo:** el Server
Component no tiene acceso al `navigator.geolocation` del browser. Las alternativas
consideradas eran (a) un header custom seteado por middleware — no aplica, Next no puede
inyectar geolocalización del cliente en un header de request; (b) mover todo el filtrado de
`/buscar` a un Client Component — reescritura mucho más grande, pierde SSR/SEO para la
página; (c) pasar `lat`/`lng` como query param, que es lo que ya sugería la consigna de la
tarea y lo que efectivamente se implementó. Redondeado a 3 decimales (~110m, la misma
precisión "city-scale" que `use-location.ts` ya usaba para el propio
`GEOLOCATION_OPTIONS`) antes de escribirlo en la URL — evita exponer la coordenada exacta
del visitante en un link que es visible y fácil de copiar/compartir, sin perder precisión
útil para "cuál está más cerca".

**Verificación — backend real, `curl` directo (`http://localhost:3000`):**
```
curl -s "http://localhost:3000/api/v1/merchants?neighborhood=Palermo" # meta.total_count: 30
curl -s "http://localhost:3000/api/v1/merchants?neighborhood=Recoleta" # meta.total_count: 0
curl -s "http://localhost:3000/api/v1/merchants?type=cafe" # meta.total_count: 6, todos type=cafe
curl -s "http://localhost:3000/api/v1/merchants?type=cafe&neighborhood=Palermo" # meta.total_count: 6 (combinado, coherente)
curl -s -w "%{http_code}" "http://localhost:3000/api/v1/merchants?type=invalid_type" # 400 {"error":"Invalid type filter value"}
curl -s "http://localhost:3000/api/v1/merchants?tags=vegano" # meta.total_count: 2
curl -s "http://localhost:3000/api/v1/merchants?price_per_person=15000" # meta.total_count: 8
curl -s -w "%{http_code}" "http://localhost:3000/api/v1/merchants?price_per_person=abc" # 400 {"error":"Invalid price_per_person filter value"}
```

**Verificación — `/buscar` real contra el backend real (servidor ya corriendo en el
worktree compartido con `NEXT_PUBLIC_API_BASE_URL=http://localhost:3000/api/v1`, puerto
3001 — no se levantó una instancia propia porque Next ya rechaza una segunda instancia sobre
el mismo directorio de proyecto):**
```
curl -s "http://localhost:3001/buscar"                                  # "30 lugares encontrados"
curl -s "http://localhost:3001/buscar?type=cafe"                        # "6 lugares encontrados" (coincide con el curl directo)
curl -s "http://localhost:3001/buscar?hood=Palermo"                     # "30 lugares encontrados"
curl -s "http://localhost:3001/buscar?hood=Recoleta"                    # "0 lugares encontrados" (antes del fix esto no filtraba nada de verdad, solo coincidía por casualidad porque todo el seed es Palermo)
curl -s "http://localhost:3001/buscar?type=cafe&hood=Palermo"           # "6 lugares encontrados" (combinado)
curl -s "http://localhost:3001/buscar?type=restaurant&price=0-20000&hood=Palermo" # "1 lugar encontrado" (triple filtro combinado, coherente)
curl -s "http://localhost:3001/buscar?tags=vegano"                      # "2 lugares encontrados"
curl -s "http://localhost:3001/buscar?lat=-34.5900&lng=-58.4200&sort=distancia"   # distancias reales y ascendentes: 0,2 / 0,3 / 0,9 / 1 / 1,2 / 1,3 / 1,5 / 1,5 / 1,6 / 1,8 km
curl -s "http://localhost:3001/buscar?lat=-34.5900&lng=-58.4200&dist=1"           # "4 lugares encontrados" — exactamente los 4 con distancia real <= 1km de la corrida anterior (0,2 / 0,3 / 0,9 / 1 km)
curl -s "http://localhost:3001/buscar"                                            # sin lat/lng: todas las cards vuelven a "0 km" (comportamiento honesto esperado, no un bug)
```
Todo lo anterior confirmado leyendo el HTML devuelto (conteo "N lugares encontrados" y las
distancias renderizadas en cada card, extraídas con `rg`).

**Limitación de metodología:** no se pudo usar `orca` para un screenshot real de la
sincronización client-side de `lat`/`lng` (requiere simular un permiso de geolocalización
real en un browser con JS, y el puerto de dev estaba en uso por otra sesión trabajando en
paralelo en el mismo worktree) — la verificación de esa parte es por lectura de código
(mismo patrón ya probado y documentado en el fix #5: `useSyncExternalStore` +
`router.replace`) más el lado servidor confirmado end-to-end arriba (que es, de hecho, la
parte que antes estaba genuinamente rota).

`pnpm lint`, `pnpm build` (41 páginas) y `pnpm test` (144 tests, 22 archivos, 3 nuevos de
este fix) corren en verde a nivel de todo el repo al momento de cerrar este fix.

**Nota de proceso — ruido transitorio por trabajo concurrente:** durante este fix, el
worktree tenía trabajo sin commitear de otra sesión en paralelo (`FavoritesTab.tsx`,
`ProfileHeader.tsx`, `SettingsTab.tsx`, `lib/favorites/`, etc. — feature de favoritos/perfil,
fuera de alcance acá). En un punto intermedio eso hizo fallar `pnpm lint` (error en
`FavoritesTab.tsx`, confirmado con `git stash` que el error persistía sin los cambios de este
fix) y, más tarde, `pnpm build` (`PerfilView.tsx` vs. `ProfileHeader.tsx`, mismatch de tipos
mientras esa otra sesión trabajaba) — ninguno son archivos tocados en este fix. Ambos se
resolvieron solos cuando esa otra sesión terminó su cambio; el estado final de arriba es el
definitivo.

### 7. Pill "Abierto ahora" faltante en el detalle de restaurante — RESUELTO

**Archivos nuevos:** `web/lib/hooks/use-open-status.ts` (hook client-only que expone el
status en vivo). **Archivos modificados:** `web/lib/mock/business-hours.ts` (nueva
`getOpenStatus`, pura y testeable, reexportada tal cual desde `lib/data/business-hours.ts`
igual que el resto de los helpers de este archivo), `web/components/features/restaurantes/MerchantDetailView.tsx`
(pill nueva entre la dirección y el pill de precio, en ambos layouts phone y wide),
`web/__tests__/lib/mock/business-hours.test.ts` (18 casos nuevos para `getOpenStatus`).

**Lógica (`getOpenStatus`, `lib/mock/business-hours.ts`):** reusa exactamente el mismo
`DayHours`/`DayShift` que ya arma `groupBusinessHoursByDay` para la tabla de horarios de
abajo (no se reinventa el parseo) y compara la hora local actual contra **dos** filas: la de
hoy (para el caso normal, o para un turno que sigue corriendo pasada la medianoche, ej.
"19:00–03:00") y la de ayer (para el caso en que el turno de ayer cruzó la medianoche y
todavía sigue abierto en la madrugada de hoy — ej. sábado 18:00–02:00 sigue "abierto" el
domingo a la 01:00 aunque el domingo esté marcado como día cerrado). No hay timezone por
merchant en el schema (`backend/db/structure.sql` guarda `opens_at`/`closes_at` como `time
without time zone`, dígitos de wall-clock literales — ver la nota de parseo en
`lib/api/merchants.ts`), así que se usa la hora local del visitante; razonable para este MVP
porque todo el producto y todos los visitantes están en Argentina.

**Por qué un hook y no cálculo directo en el render:** `/restaurantes/[id]` se genera
estático en build time (`generateStaticParams`), así que un "ahora" calculado en el server
quedaría congelado en el momento del build y sería casi siempre incorrecto para un visitante
real — el mismo motivo por el que la distancia real (fix #5) también es client-only.
`useOpenStatus` devuelve `null` hasta el primer efecto después del mount (la pill
simplemente no se renderiza hasta entonces) y se re-chequea cada 60s para que la pill cambie
sola si alguien deja la pestaña abierta cruzando el horario de apertura/cierre.

**Decisión de diseño — chevron sin duplicar la tabla:** la referencia usa el chevron para
mostrar/ocultar un acordeón inline con la semana completa. Este componente ya había tomado
la decisión (documentada en su propio comentario de cabecera) de renderizar la tabla de
horarios siempre expandida más abajo en la página, sin acordeón, por ser contenido estático.
Agregar un segundo acordeón con la misma info bajo la pill hubiera duplicado esa tabla — en
cambio, el chevron hace scroll (`scrollIntoView({behavior:"smooth", block:"start"})`) hasta
la sección "Horarios" ya existente, manteniendo una sola fuente de verdad visual para el
horario completo.

**Colores:** se reusan tokens de diseño ya existentes en `app/globals.css`
(`--color-success`/`--color-success-soft` para "Abierto ahora", el mismo verde
`#8FD46A` que usa el `.dc.html`; `--color-accent-light`/`--color-accent-soft` para "Cerrado",
el mismo `#FF7A55` — ya usado en este mismo componente para el pill de precio), no colores
nuevos.

**Verificación:**
- 18 tests nuevos en `__tests__/lib/mock/business-hours.test.ts` cubriendo: turno del mismo
  día (abre/cierra), turno que cruza medianoche (hoy y el "derrame" a ayer), un día marcado
  cerrado con el turno de ayer todavía corriendo pasada la medianoche, y dos casos con datos
  **reales** tal cual los devuelve el backend corriendo: merchant 257 (bar, Lun-Sáb
  18:00–02:00, Dom cerrado, de `GET http://localhost:3000/api/v1/merchants/257`) en un
  horario dentro del turno (abierto) y en la "zona muerta" entre el cierre de ayer y la
  apertura de hoy (cerrado).
- Verificación en vivo, hora real, contra el backend corriendo (`orca eval` sobre
  `http://localhost:3001/restaurantes/257`, miércoles ~03:50 AM real): la pill renderizada
  en el DOM real muestra `Cerrado` + `hoy 18:00–02:00` — correcto, coincide con merchant 257
  (bar 18:00–02:00) estando fuera de su turno a esa hora. Confirmado también con merchant 250
  (cafe, Mar-Dom 08:00–20:00, Lun cerrado) evaluando `getOpenStatus` con la hora real: cerrado
  también, correcto (antes de la apertura de las 08:00).
- Click en la pill confirmado con un spy sobre `Element.prototype.scrollIntoView`: dispara
  `scrollIntoView({behavior:"smooth", block:"start"})` sobre el `<section>` exacto de
  "Horarios" — el scroll visual en sí no se pudo confirmar por `scrollY` en este entorno
  (el navegador embebido de Orca no anima `behavior:"smooth"`, confirmado también probándolo
  a mano fuera del click; `behavior:"auto"` sobre el mismo nodo sí mueve `scrollY`), pero el
  spy prueba que el handler y el target son los correctos — es una limitación conocida de
  smooth-scroll en navegadores automatizados/headless, no del código.
- `pnpm lint`, `pnpm build` (41 páginas) y `pnpm test` (144 tests, 22 archivos) corren en
  verde a nivel de todo el repo.

### Qué NO se tocó (documentado en las secciones de arriba, requiere decisión de
producto/diseño o trabajo más grande)

- Botón "Delivery" en el detalle de restaurante (ver hallazgo #2 de la sección 3).
- Tratamiento visual del botón QR del nav (FAB elevado vs. ícono plano) — decisión de
  diseño ya justificada en el propio código, no un bug.
- Segmented "Lugares/Platos" con relleno naranja sólido vs. el tratamiento neutro de la
  referencia — decisión de estilo consistente con el resto de los CTAs de la app.
- Semántica de precio distinta en las cards de la referencia ($ sin "desde" vs. "desde $X"
  real) — depende de qué dato de negocio se quiera mostrar.
- Filtro de precio (`price`) en `/buscar` — se queda client-side a propósito, el backend no
  tiene un contrato de rango/banda que traducir sin cambiar la semántica (ver fix #6).
- ~~Segmented "Visitas/Favoritos/Ajustes" y puntitos de progreso por visita en Perfil~~ —
  **resuelto**, ver sección 6 ("Hallazgos #1-#4 — RESUELTOS" y el tab "Favoritos").
- Botón "Continuar con Google" en Login.
- **[Nuevo, no arreglado]** Hard-reload de `/perfil` con sesión mock válida redirige a
  `/login` (bug de hidratación en `session-provider.tsx`, preexistente — ver el cierre de la
  sección 6).
