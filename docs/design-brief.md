# Design Brief — Fudo Consumers Mobile

Fuente: `docs/design-reference/Fudo App.dc.html` (canvas interactivo tipo Claude Design) + `docs/design-reference/support.js`, contrastado contra el scaffold real en `mobile/lib/`, `PRD.md`, `PLAN.md`, `RAMBLING.md` y el schema real en `backend/db/structure.sql`.

> Nota de ruta: la exploración original de este brief se hizo sobre una carpeta `design-reference/` en la raíz del repo. Durante la tarea, un merge (`git merge --ff-only main`) trajo la ubicación definitiva de estos archivos bajo `docs/design-reference/` (contenido idéntico en `Fudo App.dc.html` y `support.js`) y eliminó el duplicado de la raíz. Todas las referencias de este documento usan ya la ruta definitiva. El merge también trajo dos archivos más en esa carpeta que **no son parte del diseño visual** (`deck-stage.js` y `fudo-design-seed.json`) — ver sección 1.5 para el segundo, que sí es relevante para el backlog de datos.

## 0. Cómo está armado el archivo de diseño (importante para quien lo retome)

`docs/design-reference/Fudo App.dc.html` **no** es un conjunto de artboards estáticos independientes. Es un único prototipo interactivo: un frame de teléfono (390×844) con una clase `Component extends DCLogic` (React-like) cuyo `state` maneja:

- `view`: `home | loading | list | map | detail | gift | profile`
- `tab`: `inicio | buscar | regalar | perfil`
- sub-estados internos: `mTab` (`loyal|menu` dentro del detalle), `pTab` (`visitas|favoritos|config` dentro de perfil), `resMode` (`lugares|platos` en resultados), y varios sheets superpuestos (`filtersOpen`, `editOpen`, `optKey`, `qrOpen`, `buying`).

Todas las "pantallas" conviven condicionalmente en un solo árbol de divs; lo que cambia entre pantallas es el `state`, no el markup. El script también trae **datos mock completos y ya usables como semilla de datos fake**: 30 merchants en Palermo/CABA (`PLACES`), menús por local (`MENUS`), frases de ejemplo del buscador (`HINTS`), reglas de fidelización por tipo de local (`LADDER`, `LGROUP`), niveles de cliente por visitas (`TIERS_L`) y tiers de gift card (`TIERS`).

`deck-stage.js` (136 KB) no se analizó en profundidad para este brief — por su nombre parece un helper de staging/deck del propio Claude Design, no contenido de producto; no aportó nada a las secciones de tokens/pantallas de abajo. `fudo-design-seed.json` sí es relevante: es un export real de datos semilla del backend (mismo shape que `backend/db/structure.sql`, no datos de UI) — se documenta en la sección 1.5, incluyendo un problema concreto que se encontró en el archivo tal como está hoy en el repo.

---

## 1. Design tokens

### Colores (de `:root` en el `<style>` del canvas)

| Token | Valor | Uso |
|---|---|---|
| `--bg` | `#14151F` | Fondo base del frame |
| Fondo body real | `#0E0F16` | Fondo detrás del frame (glow radial `#23253A → #0E0F16`) |
| `--surf` | `#1F2130` | Superficie de cards |
| `--surf2` | `#2A2C3D` | Superficie secundaria |
| `--line` | `rgba(255,255,255,0.09)` | Bordes sutiles |
| `--ink` | `#FFFFFF` | Texto principal |
| `--ink2` | `rgba(255,255,255,0.62)` | Texto secundario |
| `--ink3` | `rgba(255,255,255,0.38)` | Texto terciario / placeholders / eyebrows |
| `--nav` | `rgba(31,33,48,0.92)` | Fondo de la bottom nav (con `backdrop-filter: blur(12px)`) |
| `--shadow` | `rgba(0,0,0,0.45)` | Sombra estándar de cards |
| Acento marca | `#FF5023` | Naranja/rojo Fudo (base) |
| Acento hover | `#D03F00` | Hover de links y botón sólido naranja |
| Gradiente CTA | `linear-gradient(180deg, #FF6337, #E8431A)` | Botones principales (buscar, delivery, filtros, gift) |
| Chip precio | `rgba(255,80,35,0.16)` bg / `#FF7A55` texto | Badges de precio/rango |
| Verde reward/tag | `#8FD46A` sobre `rgba(143,212,106,0.14–0.16)` | Tags de dieta (vegano/sin TACC), badges de premio disponible, "DNI verificado" |

**Colores por tipo de local** (`TYPES` en el JS — útiles para íconos de mapa y badges):

| Tipo | Ícono Material Symbols | Color |
|---|---|---|
| restaurant / pizzeria / food_truck | `restaurant` / `local_pizza` / `local_shipping` | `#FF5023` |
| cafe / dark_kitchen | `local_cafe` / `takeout_dining` | `#8FD46A` |
| bar / brewery | `local_bar` / `sports_bar` | `#7B7BE0` |

**Gradientes de gift card por nivel** (`TIERS`):

| Nivel | Gradiente | Color de texto | Ring/glow |
|---|---|---|---|
| CLASSIC | `linear-gradient(150deg, #FF6337 0%, #E8431A 60%, #B93412 100%)` | `rgba(255,255,255,0.8)` | `rgba(255,99,55,0.6)` |
| GOLD | `linear-gradient(150deg, #3B2A14 0%, #7A5A1F 45%, #E0B95C 100%)` | `#FFE9AE` | `rgba(224,185,92,0.7)` |
| BLACK | `linear-gradient(150deg, #14151F 0%, #23253A 55%, #40435E 100%)` | `#C9CCE0` | `rgba(201,204,224,0.6)` |
| PLATINUM | `linear-gradient(150deg, #1B1533 0%, #3A2A78 48%, #6E5AC8 100%)` | `#D6CBFF` | `rgba(150,124,232,0.75)` |

Montos por defecto: Classic `$12.000`, Gold `$40.000`, Black `$120.000`, Platinum: monto libre entre `$121.000` y `$1.000.000`.

**Niveles de cliente por visitas totales** (`TIERS_L`, independiente por local vía `tierOf`, con paleta propia para el "hero" de fidelización):

| Nivel | Umbral (visitas) | Gradiente |
|---|---|---|
| CLIENTE FIJO | ≥10 | `linear-gradient(150deg, #1B1533 0%, #3A2A78 48%, #6E5AC8 100%)` |
| NIVEL ORO | ≥8 | `linear-gradient(150deg, #3B2A14 0%, #7A5A1F 45%, #E0B95C 100%)` |
| NIVEL PLATA | ≥4 | `linear-gradient(150deg, #1B1C2A 0%, #33364B 55%, #5A5F7D 100%)` |
| NIVEL BRONCE | ≥1 | `linear-gradient(150deg, #2A160E 0%, #7A3A1C 55%, #E8703A 100%)` |
| SIN VISITAS AÚN | 0 | `linear-gradient(150deg, #1A1B26 0%, #24263A 100%)` |

(Nota: en el código de filtrado hay un `tierOf` más simple y hardcodeado — Bronce <4, Plata 4-7, Oro ≥8 — que difiere levemente de la tabla visual `TIERS_L`. Al implementar, conviene unificar esta regla de negocio en un solo lugar.)

### Tipografía

- **Barlow** (600, 700, 800, 900, itálica 900) — títulos, headlines, montos grandes, nombres de local.
- **Inter** (300–700) — texto de cuerpo, inputs, botones.
- **Material Symbols Outlined** (`opsz,wght,FILL,GRAD@24,200,0,0`) — todos los íconos, variable weight típico 200–300.

### Radios, sombras y espaciado

- Frame del teléfono: `border-radius: 46px`.
- Cards de contenido: `16–18px`; contenedores grandes/hero: `20–26px`; fotos pequeñas: `12–13px`; botones/pills/switches: `999px` (full pill).
- Sombra estándar de card: `box-shadow: 0 24px 50px var(--shadow), inset 0 1px 0 var(--hi)`.
- Botones CTA con glow de color: `box-shadow: 0 8-10px 20-24px rgba(255,80,35,0.38)`.
- Bottom sheets: `border-radius: 26px 26px 0 0`.

### Animaciones (keyframes definidos globalmente, uso confirmado por pantalla)

| Keyframe | Efecto | Dónde se usa |
|---|---|---|
| `fudoIn` | entrada con fade + translateY(14px) | Transición entre vistas principales, sub-tabs de perfil (Visitas/Favoritos/Config), cards de plato en resultados, mini-card flotante sobre el mapa, entrada al detalle |
| `fudoFade` | fade simple | Contenedor de Home, de Loading, de Mapa, transición interna Escanear↔Mi QR |
| `fudoPulse` | scale+opacity pulsante | Ícono `auto_awesome` en la pantalla de loading de búsqueda |
| `fudoCaret` | parpadeo de cursor `\|` | Cursor del placeholder animado tipo typewriter en el buscador |
| `fudoShimmer` | barrido de brillo horizontal | Skeletons de carga (loading y resultados) |
| `fudoDrop` | caída con overshoot | Pines del mapa al aparecer (con delay escalonado) |
| `fudoZoom` | zoom-out sutil al cargar | Imagen hero del restaurante en el detalle |
| `fudoGlow` | opacidad pulsante | Definido pero no confirmado en el markup estático leído — probablemente resuelto dinámicamente vía JS en algún halo/glow |
| `fudoSheet` | slide-up del panel | Entrada de todos los bottom sheets (filtros, edición, opciones, QR) |
| `fudoVeil` | fade del backdrop | Overlay oscuro detrás de cada bottom sheet y del overlay de compra exitosa |
| `fudoScan` | barrido vertical de línea de escaneo | Línea de escaneo del QR (loop infinito, 2.4s) |
| `fudoSheen` | brillo diagonal recorriendo la superficie | Card hero de fidelización, cards de tier de gift card, botón de compra final, (probablemente) la card ganadora del regalo |
| `fudoCardWin` | scale+rotate de entrada | Definido, asociado conceptualmente a la card de gift card ganadora (`wonCardStyle`), resuelto dinámicamente en JS — no confirmado literal en el HTML estático |
| `fudoConfetti` | partículas volando con `--dx/--dy/--rot` | Confetti del overlay de "Gift card enviada" (16 partículas, estilo generado por JS) |
| `fudoStamp` | scale-in con overshoot | Texto "¡Gift card enviada!" en el overlay de éxito |
| `fudoRing` | anillo expandiéndose y desvaneciéndose | Dos anillos concéntricos en el overlay de éxito de compra (delays escalonados) |

---

## 1.5 Schema real del backend y estado del fixture de datos

`PLAN.md` (Fase 2) es explícito: los frontends **no inventan su propio shape de datos** — consumen fixtures locales (`mobile/assets/fixtures/*.json`) generados a partir del schema real (`backend/db/structure.sql`, 14 tablas + 7 enums) detrás de una interfaz abstracta (`lib/data/local/local_data_source.dart`) que en Fase 4 se reemplaza por `remote_data_source.dart` sin tocar las pantallas. Esto es más estricto que "usá modelos Dart simples con datos hardcodeados" a secas: los modelos Dart de esta app deben reflejar los campos reales del schema, no los nombres/forma que usa el JS del prototipo de diseño (que son solo para maquetar la demo visual).

**Tablas y enums reales** (`backend/db/structure.sql`):

| Tabla | Columnas clave | Enum asociado |
|---|---|---|
| `merchants` | `name`, `type`, `address/country/state/city/neighborhood/zip_code`, `latitude/longitude`, `cover_image_url`, `whatsapp_number`, `delivery_url`, `price_per_person_min/max` | `merchant_type_enum`: `restaurant, cafe, bar, dark_kitchen, pizzeria, brewery, food_truck, other` |
| `menu_items` | `merchant_id`, `name`, `description`, `price`, `currency`, `section`, `image_url`, `active` | `currency_enum`: `usd, ars` |
| `business_hours` | `merchant_id`, `day_of_week`, `opens_at`, `closes_at`, `closed` (sin unique constraint — permite doble turno el mismo día) | `day_of_week_enum`: `monday…sunday` |
| `tags` / `merchants_tags` / `menu_items_tags` | tablas de unión simples | — |
| `consumers` | `first_name/last_name`, `email`, `password_hash` (bcrypt, sin campos OAuth), `dni_encrypted` + `dni_bidx` (Lockbox), `phone` | — |
| `consumer_settings` | `consumer_id`, `theme`, `notifications_enabled` | `theme_enum`: `light, dark, system` |
| `loyalty_rules` | `merchant_id`, `visits_required`, `reward_type`, `reward_description`, `is_permanent` | `reward_type_enum`: `discount_percent, free_item, cashback, other` |
| `visits` | `consumer_id`, `merchant_id`, `amount`, `reward_applied`, `reward_description_snapshot`, `visited_at` | — |
| `visit_summaries` | `consumer_id`, `merchant_id`, `count`, `current_tier`, `last_visit_at` | — |
| `favorites` | `consumer_id`, `merchant_id` | — |
| `gifts` | `sender_consumer_id`, `recipient_consumer_id`, `type`, `amount`, `recipient_phone`, `message`, `expires_at`, `status` | `gift_type_enum`: `classic, gold, black, platinum` · `gift_status_enum`: `pending, redeemed, expired, cancelled` |
| `search_history` | `consumer_id`, `query_text`, `structured_output` (jsonb) | — |

Esto confirma dos cosas del diseño ya anotadas más arriba: (1) `gift_type_enum` tiene exactamente los 4 niveles del prototipo (classic/gold/black/platinum → el `custom` del JS del diseño es `platinum`); (2) `consumers` no tiene ningún campo de OAuth — el backend tampoco soporta login con Google, coherente con que el botón "Continuar con Google" del diseño es puramente decorativo y no debe implementarse.

Gap adicional detectado acá: `merchant_type_enum` tiene un 8vo valor, `other`, que el diseño no contempla en su mapa `TYPES` (que solo cubre los 7 tipos con ícono/color propios) — el modelo Dart y el mapeo ícono/color necesitan un caso default para `other`.

**⚠️ Estado real de `docs/design-reference/fudo-design-seed.json` — no está listo para copiarse tal cual.** Es, en efecto, un export de datos semilla reales con el shape del schema de arriba (se confirmaron registros de `merchants`, `menu_items`, `business_hours`, `tags`, `merchants_tags`, `menu_items_tags`, `consumers`, `loyalty_rules`, `visits` y `visit_summaries`) — pero el archivo tal como está en el repo **es JSON inválido**: pesa exactamente 262.144 bytes (256 KiB, un número de archivo truncado, no un tamaño de contenido real) y corta a mitad de un string en el registro de `visits` con id 79, sin cerrar ninguna de las estructuras abiertas. Faltan, al menos, las secciones de `consumer_settings`, `favorites`, `gifts` y `search_history` que si el archivo estuviera completo deberían aparecer. **No se puede usar como fixture real hasta regenerarlo** (correr de nuevo el `rake export:fixtures` que describe `PLAN.md` Fase 1, o pedir el archivo completo de nuevo). Mientras tanto, el backlog de abajo asume que hay que trabajar con un subconjunto de datos de ejemplo consistente con el schema (se puede partir de los 30 merchants/menús que ya están en el JS del diseño, remapeados a los nombres de columna reales) hasta que el fixture real esté disponible completo.

---

## 2. Pantallas y flujos

### 2.1 Home / landing de búsqueda (`view: home`, `tab: inicio`)
- Fondo con glow radial naranja + partículas decorativas, status bar simulada, logo Fudo + botón de ubicación.
- Headline: **"Encontrá dónde comer."** / **"Ganá descuentos por cada visita."** (segunda línea con "Ganá descuentos" en itálica naranja) — coincide textual con la frase ya definida en `RAMBLING.md`.
- Card de búsqueda flotante con placeholder animado tipo typewriter que rota por `HINTS`: *"Algo picante y barato cerca mío"*, *"Café tranquilo para laburar en Palermo"*, *"Parrilla para ir con amigos esta noche"*, *"Opción sin TACC para almorzar"*, *"Sushi que no sea carísimo"*.
- Selector de tipo de búsqueda + botón circular de submit.
- Bloque opcional **"CONTINUAR BÚSQUEDA"** con la última query, si existe.
- Animaciones: `fudoFade` en el contenedor, `fudoCaret` en el cursor del placeholder.

### 2.2 Loading de búsqueda (`view: loading`)
- Ícono `auto_awesome` pulsante + **"Buscando los mejores lugares para vos…"** + la query citada en itálica + 3 skeletons con shimmer.
- Delay simulado: 550ms (búsqueda por nombre) / 950ms (búsqueda por IA).
- Animaciones: `fudoFade`, `fudoPulse`, `fudoShimmer`.

### 2.3 Lista de resultados (`view: list`, `tab: buscar`)
- Header: input de búsqueda (placeholder **"Buscar por nombre, tipo o barrio"**) + botón limpiar + botón de filtros con badge de conteo.
- Toggle Lista/Mapa (`resMode`: `lugares`/`platos` para el tipo de resultado, más un toggle aparte lista↔mapa).
- Chips horizontales de sugerencias IA (con ícono `auto_awesome`), generados a partir de qué reglas de `AI` matchearon el texto buscado.
- Cards de lugar: foto + badge de categoría, nombre, favorito, meta, plato destacado, chip de precio, distancia, badge verde de premio disponible si aplica.
- Vista alternativa de platos individuales (cross-merchant).
- Paginación: scroll infinito de a 10 resultados, con "cargar más" fake (750ms).
- Copy de contador: **"1 coincidencia"/"{n} coincidencias"**, **"1 lugar"/"{n} lugares"**, **"1 plato"/"{n} platos"**.
- Estado vacío: ícono `search_off` + título dinámico (ej. `Sin resultados para "{query}"` / `Ningún lugar con esos filtros`) + botón **"Limpiar búsqueda"** / **"Limpiar filtros"**.
- Animaciones: `fudoIn` en contenedor y cards de plato, `fudoShimmer` en skeletons.

### 2.4 Mapa de resultados (`view: map`)
- Mapa dibujado con divs (en el prototipo; en la app real ya existe integración con `flutter_map` + tiles CartoDB Dark Matter, que es el approach correcto a mantener).
- Pines coloreados por tipo de local con animación `fudoDrop` escalonada.
- Mini-card flotante al tocar un pin (foto, nombre, meta, precio, distancia) con `fudoIn`.
- Botón flotante para alternar a lista.

### 2.5 Detalle de restaurante (`view: detail`, `tab: buscar`)
- Header con foto full-width, overlay gradiente, botones volver/favorito flotantes.
- Nombre, meta, dirección, acordeón de horarios (**"Abierto ahora"/"Cerrado"**, detalle día por día).
- Botones de acción: **WhatsApp** y **Delivery** (deep-link a WhatsApp/delivery del local — consistente con lo que dice `RAMBLING.md` sobre el mapa de locales).
- Sub-tabs internos (`mTab`): **Mis visitas** (fidelización) / **Menú**.
  - **Mis visitas**: card hero con gradiente de nivel, círculo de progreso de visitas, timeline **"TU CAMINO EN {NIVEL}"** con pasos numerados, premios, badges **"ESTÁS ACÁ"** / **"PRÓXIMO"**; nota final invitando a escanear el QR. Copy de estado: *"Sos cliente fijo"*, *"Arrancá tu camino"*, *"Falta 1 visita para tu próximo premio"* / *"Faltan {n} visitas para tu próximo premio"*.
  - **Menú**: agrupado por categoría, cards de plato con imagen, tags de dieta, precio en Barlow + "ARS".
- Animaciones: `fudoIn` al entrar, `fudoZoom` en la foto hero, `fudoSheen` en la card hero de fidelidad.

### 2.6 Regalar / gift cards (`view: gift`, `tab: regalar`)
- Título **"Regalar"** + copy **"Elegí una gift card de Fudo para usar en cualquier local de la red."**
- Carrusel de 4 tiers (Classic/Gold/Black/Platinum) con monto, beneficio (`t.perk`) y efecto `fudoSheen`.
- Monto personalizado solo para Platinum, con validaciones: **"Usá solo números"**, **"El mínimo es $121.000"**, **"El máximo es $1.000.000"**, **"Entre $121.000 y $1.000.000"**.
- Formulario **"PARA QUIÉN"**: teléfono del destinatario + mensaje opcional.
- Botón CTA dinámico: **"Corregí el monto"** / **"Ingresá un monto"** / **"Comprar y enviar {monto}"**.
- **No hay pasarela de pago real** en el prototipo: "comprar" dispara directo un overlay de éxito.
- Overlay de éxito (`buying`): dos anillos `fudoRing`, confetti (`fudoConfetti`), card ganadora con el gradiente del tier + `fudoSheen`, texto **"¡Gift card enviada!"** con `fudoStamp`, destinatario, botón **"Listo"**. Si no se completó el teléfono, el copy cae a **"Lista para compartir por WhatsApp"** en vez de **"Enviada a {teléfono}"**.

### 2.7 Login / Perfil / Mis Lugares (`view: profile`, `tab: perfil`)
- **Estado deslogueado** ("Bienvenido"): logo, **"Ingresá a tu cuenta de Fudo"**, botón **"Continuar con Google"** (outline), separador **"o con email"**, inputs `tu@email.com` / `Tu contraseña`, botón sólido **"Iniciar sesión"**, link **"¿No tenés cuenta? Registrate"**.
  - ⚠️ El botón de Google es **decorativo**: no tiene ningún handler asociado en el JS (`login()` solo hace `setState({ user: "martina" })` ignorando email/password). Es puro mock visual.
- **Estado logueado**, header con avatar+iniciales, nombre, email, badge de nivel top. Sub-tabs pill (`pTab`): **Visitas / Favoritos / Ajustes**.
  - **Visitas**: **"LUGARES QUE VISITASTE"**, cards con sellos de fidelización (stamps) por local y badge de nivel.
  - **Favoritos**: **"TUS FAVORITOS"**, lista con imagen+nombre+meta+botón quitar. Estado vacío: ícono `favorite_border` + **"Marcá lugares con el corazón y aparecen acá."**
  - **Ajustes**: secciones **"DATOS PERSONALES"** (editable vía sheet: Nombre/Apellido/Email/Teléfono), **"PREFERENCIAS"** (tema claro/oscuro, notificaciones, alertas de precio, fila fija de DNI con badge **"Verificado y cifrado"**), **"SEGURIDAD Y CUENTA"** (restablecer contraseña, cerrar sesión, eliminar cuenta con doble-tap de confirmación **"Tocá de nuevo para confirmar"**). Footer: *"Miembro desde marzo 2025 · datos actualizados hace 2 días · ID {qrId}"*.

### 2.8 Sheet de QR de fidelización (`qrOpen`)
- Título **"Tu código Fudo"**, tabs **"Mi QR"** / **"Escanear"**.
- Escanear: recuadro con mira naranja + línea de barrido animada (`fudoScan`, loop 2.4s), **"Escaneá el QR del local"**, **"Se suma la visita y aplicamos tu descuento al instante."**
- Mi QR: QR generado (grid CSS fake), **"Mostrale este código al mesero para validar tu visita."**, badge **"ID {qrId}"**.
- Accesible desde un botón central persistente en la bottom nav (no es un tab más, es una acción rápida).

### 2.9 Filtros avanzados (`filtersOpen`, bottom sheet)
- Categorías: **Básico** (orden, tipo de local, disponibilidad), **Precio** (rango, dieta), **Platos** (precio de plato, sección de menú, apto para), **Ubicación** (barrio, distancia), **Premios** (programa de visitas, mi nivel Bronce/Plata/Oro).
- Toggle **"Ocultar visitados"**, botones **"Limpiar"** / **"Aplicar"** con conteo de filtros activos.

### 2.10 Bottom navigation
- Pill central flotante con blur, tabs a la izquierda y derecha del botón QR central, labels que se expanden solo en el tab activo.
- **Importante (ver sección de gaps)**: el prototipo modela 4 destinos de nav (`inicio`, `buscar`, `regalar`, `perfil`) + acción central de QR, mientras que el PRD y el scaffold definen 3 tabs (Buscar/Mis Lugares/Regalar).

---

## 3. Reglas de negocio relevantes ya resueltas en el prototipo (útiles para el backlog)

- **Búsqueda en lenguaje natural**: normaliza texto (sin tildes/mayúsculas). Si matchea el nombre de un local (≥3 caracteres) usa modo nombre literal; si no, evalúa regexes (`AI`) para picante/económico/cerca/vegano/sin TACC/abierto ahora y activa los chips correspondientes; si ninguno matchea, cae por defecto en "cerca" (radio ≤2.6km).
- **Fidelización por local**: agrupa el tipo de negocio en `food/cafe/bar/delivery` (`LGROUP`) y usa una escalera de premios por grupo (`LADDER`, tope 10 visitas visualizadas); al agotar la escalera, el usuario pasa a "cliente fijo" con 5% permanente.
- **Nivel de cliente por local**: Bronce (<4 visitas), Plata (4–7), Oro (≥8) — regla simple, separada de la paleta visual de 5 niveles (`TIERS_L`) que además agrega "Cliente fijo" (≥10) y "Sin visitas aún" (0).
- **Horarios**: generados matemáticamente a partir del id del local (no hay fecha real, "hoy" está hardcodeado a miércoles).
- **Precios de menú**: escalados por tipo de merchant y redondeados a múltiplos de $500.
- **Gift card**: sin pasarela de pago real, solo validación de monto (Platinum) y overlay de éxito.
- **Login**: 100% fake (no valida credenciales), sin integración Google real pese al botón visible.
- **Favoritos**: toggle en memoria, sin persistencia.

---

## 4. Gap actual — scaffold (`mobile/lib`) vs diseño

### Confirmado: el theme del scaffold NO coincide con el diseño

`mobile/lib/core/theme/app_theme.dart` usa `_background = #0A0A0C`, `_surface = #16161A` y `_violetAccent = #8B5CF6` (`ColorScheme.fromSeed`), con el propio comentario del archivo aclarando que es un placeholder ("real visual design comes from a Claude Design prototype, not yet shared"). El diseño real usa `#14151F`/`#0E0F16` de fondo, `#1F2130`/`#2A2C3D` de superficie y **`#FF5023` naranja/rojo** como acento — confirmado, no coinciden en ningún color. Tampoco están importadas las fuentes Barlow/Inter ni Material Symbols Outlined (el scaffold usa las fuentes/íconos default de Flutter).

### Gap de estructura de navegación (a decidir con producto)

El diseño modela **4 destinos** de bottom nav (`inicio`, `buscar`, `regalar`, `perfil`) más un botón central de QR, mientras que el PRD y `RAMBLING.md` son explícitos en **3 tabs**: Buscar / Mis Lugares / Regalar. Lectura más probable (asumida para el backlog, a confirmar): el `inicio` del diseño es el estado inicial de la tab **Buscar** (antes de ejecutar una búsqueda) y el `perfil` del diseño es el contenido de la tab **Mis Lugares** (perfil + fidelización, tal como pide el PRD). El botón central de QR sería una acción rápida transversal, no una tab nueva. Esto **no está resuelto en el PRD** y conviene confirmarlo antes de fijar el árbol de rutas definitivo.

### Pantalla por pantalla

| Pantalla del diseño | Estado en `mobile/lib` |
|---|---|
| Home/landing de búsqueda (headline, typewriter, card de búsqueda) | No existe. `search_screen.dart` solo tiene un `AppBar` y el texto fijo "Buscar" |
| Loading de búsqueda | No existe |
| Lista de resultados (cards, chips IA, filtros, favoritos) | No existe |
| Mapa de resultados con pines por tipo | Parcial: ya hay un `FlutterMap` funcional con tiles CartoDB Dark Matter (coincide con el PRD), pero sin marcadores, sin búsqueda, sin toggle lista/mapa |
| Filtros avanzados (bottom sheet) | No existe |
| Detalle de restaurante (horarios, WhatsApp/delivery, loyalty, menú) | No existe — no hay ni siquiera un modelo de "Merchant"/"Restaurant" |
| QR de fidelización (escanear/mostrar) | No existe. El paquete `mobile_scanner: ^7.4.0` ya está en `pubspec.yaml` pero no se usa en ningún archivo |
| Regalar (tiers, monto custom, checkout, overlay de éxito) | No existe. `gifting_screen.dart` es un placeholder `Center(Text('Regalar'))` |
| Login (email+contraseña) | No existe. (El diseño muestra también un botón "Continuar con Google" que es decorativo en el prototipo y que **no debe implementarse** — el PRD excluye login con Google del MVP) |
| Perfil/Mis Lugares (visitas con sellos, favoritos, ajustes) | No existe. `my_places_screen.dart` es un placeholder `Center(Text('Mis Lugares'))` |
| Modelos de datos (Merchant, Dish, GiftTier, Visit, LoyaltyLadder) | No existen en absoluto — no hay carpeta `models/` en ningún feature |
| Datos fake/mock (los 30 merchants de Palermo, menús, hints de búsqueda) | No existen — pero ya están completamente definidos y listos para portar desde el JS del diseño (`PLACES`, `MENUS`, `HINTS`, `LADDER`, `TIERS`, `TIERS_L`) |
| Estado (Riverpod) | `flutter_riverpod` está en `pubspec.yaml` y `main.dart` envuelve la app en `ProviderScope`, pero no hay ningún provider definido en ningún feature |
| Rutas (go_router) | Solo 3 rutas planas dentro de un `ShellRoute` (`/search`, `/my-places`, `/gifting`); no hay sub-rutas para detalle de restaurante, checkout de regalo, ni modales/sheets |
| Bottom nav visual | Existe (`BottomNavigationBar` estándar de Material con 3 íconos genéricos), pero no se parece al pill-nav flotante con blur y botón central de QR del diseño |
| Analytics (`posthog_flutter`) | Está en `pubspec.yaml`, no inicializado ni usado en ningún archivo |
| Cliente HTTP (`dio`) | Scaffold vacío en `dio_client.dart`, sin baseURL ni interceptors — correcto tal cual está, dado que no hay backend todavía |

---

## 5. Backlog priorizado

**Criterio rector explícito (prioridad #1 del dueño del proyecto): que el frontend Flutter se parezca lo más posible al diseño de Claude Design — colores, tipografías, copy exacto, animaciones — por encima de cualquier otra consideración de arquitectura o prolijidad de código.** Ante un conflicto entre "hacerlo lindo/fiel al diseño ya" y "hacerlo con la abstracción de datos perfecta", gana la fidelidad visual; la arquitectura de datos de abajo (fixtures + interfaz abstracta) es el mínimo necesario para no bloquear la Fase 4 después, no un fin en sí mismo.

Todo el backlog sigue el patrón de **Fase 2 de `PLAN.md`**: datos locales desde `mobile/assets/fixtures/*.json` (con el shape real de `backend/db/structure.sql`, no un shape inventado) leídos a través de `lib/data/local/local_data_source.dart`, que implementa la misma interfaz abstracta que en Fase 4 va a implementar `lib/data/remote/remote_data_source.dart` — el swap debe ser de una línea en el provider/DI (Riverpod), no un rewrite. Sin llamadas HTTP reales todavía (`dio_client.dart` queda como está). Fuera de alcance explícito en todo el backlog: delivery propio, reservas/ocupación de mesas en vivo, crédito compartido entre restaurantes, tocar el QR de Fudo Comensal/Pay, login con Google, KYC real de DNI, saldo parcial en gift cards, timezone múltiple.

1. **Theme y design tokens reales** — `mobile/lib/core/theme/app_theme.dart` (reemplazar por completo: colores `#14151F`/`#0E0F16`/`#1F2130`/`#2A2C3D`, acento `#FF5023`, `ColorScheme` custom en vez de `fromSeed` violeta), agregar fuentes Barlow + Inter (via `google_fonts` o assets bundleados) y el paquete de íconos Material Symbols Outlined. Es la base visual de todo lo demás — máximo impacto, bloquea el resto, y es el ítem más directamente alineado con el criterio rector de fidelidad visual.

2. **Modelos de dominio con el shape real del backend** — `mobile/lib/data/models/merchant.dart`, `menu_item.dart`, `business_hour.dart`, `loyalty_rule.dart`, `visit.dart`, `visit_summary.dart`, `gift.dart`, `favorite.dart` (campos y enums calcados de `backend/db/structure.sql`, no inventados: `MerchantType` con el 8vo valor `other`, `GiftType` classic/gold/black/platinum, `RewardType`, `GiftStatus`, etc.). Los datos visuales del diseño (gradientes por tier, íconos por tipo, copy de fidelización) se modelan como una capa de presentación separada que mapea sobre estos enums, no como parte del modelo de datos.

3. **Fixtures + capa de datos local** — `mobile/assets/fixtures/merchants.json`, `menu_items.json`, `business_hours.json`, `loyalty_rules.json` (y el resto de tablas relevantes para "Mis Lugares"/"Regalar" si el tiempo alcanza), más `mobile/lib/data/local/local_data_source.dart` implementando una interfaz `mobile/lib/data/data_source.dart` abstracta. **Bloqueante real:** el fixture ideal (`docs/design-reference/fudo-design-seed.json`) está truncado (ver sección 1.5) — hay que pedir que se regenere, o mientras tanto armar un fixture manual chico y consistente con el schema partiendo de los 30 merchants/menús ya definidos en el JS del diseño (`PLACES`/`MENUS` de `Fudo App.dc.html`), remapeados a los nombres de columna reales.

4. **Home/landing de búsqueda** — reemplazar el body de `search_screen.dart`: headline "Encontrá dónde comer. Ganá descuentos por cada visita.", card de búsqueda con placeholder animado (rotando las frases de ejemplo), bloque "continuar última búsqueda". Alto impacto visual, es la primera pantalla que ve cualquier usuario — prioridad alta también por el criterio rector.

5. **Lista de resultados + loading state** — `mobile/lib/features/search/widgets/search_loading_view.dart`, `search_results_list.dart`: cards de merchant, chips de sugerencia IA (evaluando las regexes de detección de intención sobre el texto tipeado — picante/económico/cerca/vegano/sin TACC/abierto ahora), favoritos, estado vacío, filtro básico de texto.

6. **Mapa de resultados con marcadores** — extender el `FlutterMap` ya existente en `search_screen.dart` con marcadores por tipo de local (color/ícono según `MerchantType`) y mini-card flotante al tocar un pin; toggle lista/mapa.

7. **Detalle de restaurante** — nueva ruta + `mobile/lib/features/search/restaurant_detail_screen.dart`: header con foto, horarios (acordeón, usando `business_hours` — recordar que puede haber doble turno el mismo día), botones WhatsApp/Delivery (via `url_launcher`, ya en `pubspec.yaml`), sub-tabs Menú / Mis visitas (timeline de fidelización usando `loyalty_rules` + `visit_summaries` del usuario para ese local).

8. **Filtros avanzados (bottom sheet)** — `mobile/lib/features/search/widgets/filters_sheet.dart`: categorías básico/precio/platos/ubicación/premios, tal como en el diseño.

9. **Mis Lugares / Perfil** — `mobile/lib/features/my_places/`: login fake (solo email+contraseña, **sin botón de Google** — ni el diseño lo implementa de verdad ni el schema del backend tiene campos OAuth), sub-tabs Visitas (con sellos por local, usando `visit_summaries`) / Favoritos (`favorites`) / Ajustes (datos personales editables, preferencias de `consumer_settings`, cerrar sesión, eliminar cuenta con doble confirmación).

10. **QR de fidelización** — `mobile/lib/features/loyalty/qr_sheet.dart` (o dentro de `my_places`, a definir): tabs Mi QR / Escanear, integrando el paquete `mobile_scanner` ya presente en `pubspec.yaml` pero sin usar. Reutilizable desde el botón central de la bottom nav y desde el detalle de restaurante. Este QR es el de fidelización de la app, no toca el QR de pedidos/pago existente de Fudo Comensal/Pay (fuera de alcance).

11. **Regalar (gift cards)** — `mobile/lib/features/gifting/`: reemplazar el placeholder actual por carrusel de tiers (Classic/Gold/Black/Platinum, usando `GiftType`) con los gradientes reales, monto custom validado para Platinum, formulario de destinatario, overlay de éxito con confetti/stamp. Sin pasarela de pago real (tal como en el prototipo).

12. **Bottom nav rediseñada** — `mobile/lib/shared/widgets/main_shell.dart`: pill flotante con blur, íconos Material Symbols, botón central de acceso rápido al QR. Requiere primero resolver la decisión de producto sobre si "Inicio" es un estado de la tab Buscar o una tab propia (ver sección de gaps) — no bloquear el resto del backlog por esto, se puede implementar inicialmente sobre las 3 tabs del PRD y ajustar después.

13. **Analytics e instrumentación** — inicializar `posthog_flutter` (ya en `pubspec.yaml`) con eventos básicos de navegación entre tabs y búsquedas, una vez las pantallas de los puntos anteriores existan.
