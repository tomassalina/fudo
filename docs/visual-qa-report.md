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
- [x] Fixes aplicados (pendientes de commit): nav flotante tapaba el final del scroll en
  Inicio/Buscar/Detalle, precio de card partido en 2 líneas en Inicio/Buscar, faltaba ícono
  de lupa en `/buscar` (ver "Fixes aplicados" #2-#4). Verificado con `pnpm lint` / `pnpm
  build` / `pnpm test` (127 tests) y capturas a viewport real 390×844.

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

1. **[CRÍTICO] Falta el header completo.** La referencia tiene, arriba del todo: logo
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

3. **[BUG] Distancia siempre "0 km".** Todas las cards de "Lugares destacados" muestran
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

7. **[BUG, mismo root cause que Inicio] Distancia "0 km" en todas las cards** — mismo
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

1. **[FALTA] Pill "Abierto ahora".** Referencia: entre la dirección y el pill de precio hay
   una píldora completa con ícono de reloj, texto verde "Abierto ahora", el horario de hoy
   ("hoy 12:00 – 00:30") y un chevron para expandir. **La real no tiene este elemento en
   absoluto** — pasa directo de la dirección al pill de precio. El dato sí existe (la tabla
   de horarios de abajo lo prueba), pero no hay resumen de estado "abierto/cerrado ahora"
   arriba. Requiere lógica de negocio (calcular abierto/cerrado según hora actual +
   huso horario) — no es un fix de CSS, queda documentado.

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

5. **[BUG, mismo root cause de siempre] Distancia "0 km"** en vez de una distancia real
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
- **Distancia "0 km" en todos lados**: consecuencia directa de que el header con
  "Activar ubicación" no existe en la implementación real. No se toca (requiere flujo de
  geolocalización completo, es una feature grande).
- **Falta el header global (logo FUDO + Activar ubicación)** en todas las páginas mobile
  revisadas. No se toca — es una decisión de layout grande, no un detalle visual suelto.
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
nueva, no solo CSS) — quedan documentados para decisión de producto/diseño, no los tocamos.

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

### Qué NO se tocó (documentado en las secciones de arriba, requiere decisión de
producto/diseño o trabajo más grande)

- Header global faltante (logo FUDO + "Activar ubicación") en Inicio/Buscar/Detalle.
- Distancia "0 km" en todos lados (depende del header de arriba — geolocalización real).
- Pill "Abierto ahora" y botón "Delivery" en el detalle de restaurante.
- Tratamiento visual del botón QR del nav (FAB elevado vs. ícono plano) — decisión de
  diseño ya justificada en el propio código, no un bug.
- Segmented "Lugares/Platos" con relleno naranja sólido vs. el tratamiento neutro de la
  referencia — decisión de estilo consistente con el resto de los CTAs de la app.
- Semántica de precio distinta en las cards de la referencia ($ sin "desde" vs. "desde $X"
  real) — depende de qué dato de negocio se quiera mostrar.
- Segmented "Visitas/Favoritos/Ajustes" y puntitos de progreso por visita en Perfil.
- Botón "Continuar con Google" en Login.
