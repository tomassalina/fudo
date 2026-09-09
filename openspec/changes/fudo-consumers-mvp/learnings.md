# Learnings — Fudo Consumers MVP (sesión de rediseño e integración end-to-end)

Continuación de `design.md` (Decisiones 1-13, fases tempranas de planificación). Este archivo documenta las decisiones de arquitectura/producto y los aprendizajes no obvios de una sesión larga y posterior (madrugada del 2026-09-09, decenas de subagentes en paralelo, todo en `main` sin worktrees) donde se llevó Next.js y Flutter a paridad pixel-perfect con el diseño de referencia y conectados de punta a punta al backend real. Ninguna de estas decisiones estaba en `design.md` — vivían solo en mensajes de commit, en `docs/visual-qa-report.md`, en `docs/flutter-vs-nextjs-gap-report.md` y en `NEXT_STEPS_CONTEXT.md` (archivo temporal, no comiteado). Mismo formato que `design.md`: qué se decidió y por qué, incluyendo alternativas descartadas, para que cualquier agente o persona sin contexto previo no tenga que reconstruir la discusión.

## Decisión 14: `Fudo Customers.dc.html` reutiliza `Fudo App.dc.html` como layout phone (vw<900)

**Fecha:** 2026-09-08/09
**Estado:** Aceptada

**Decisión:** `Fudo Customers.dc.html` (agregado en el commit `2e46d2c`) es la referencia de diseño **wide/desktop únicamente** (vw≥900). Para vw<900 la referencia canónica sigue siendo `Fudo App.dc.html` (el diseño mobile original). El propio proyecto usa 900px como breakpoint para decidir cuál referencia mirar (confirmado en `docs/visual-qa-report.md`, sección de metodología).

**Por qué:** Se construyó primero el diseño mobile (`Fudo App.dc.html`) y luego se agregó la capa wide (`Fudo Customers.dc.html`) como una extensión, no como un rediseño completo desde cero — reduce trabajo de diseño duplicado y mantiene consistencia visual entre plataformas/anchos.

**Implicación para quien edite el diseño:** si cambiás algo del layout phone (nav, cards, tipografía base), **editalo en `Fudo App.dc.html`**, no en `Fudo Customers.dc.html` — este último solo debe llevar los agregados/diferencias específicas de vw≥900 (ej. sidebar fijo de Perfil, sidebar de filtros en Buscar, split lista/mapa). Editar el layout phone únicamente en `Fudo Customers.dc.html` lo dejaría inconsistente con la experiencia mobile real, que es la prioridad del proyecto (ver `design.md`, Decisión 10).

## Decisión 15: Auth JWT persistido en `localStorage` (no httpOnly cookie) — limitación de seguridad aceptada

**Fecha:** 2026-09-09
**Estado:** Aceptada, con tradeoff documentado en código

**Decisión:** El JWT de sesión en la web (Next.js) se persiste en `localStorage` (`web/lib/auth/token-storage.ts`), no en una cookie `httpOnly`. Implementado en el commit `0fcda09`.

**Por qué:** El backend Rails devuelve el token en el body JSON de la respuesta (sin `Set-Cookie`), y hoy no hay SSR de datos privados en la web — ambas condiciones necesarias para que una cookie `httpOnly` aporte valor real ya están ausentes. Se evaluó explícitamente el tradeoff XSS-vs-httpOnly y se aceptó `localStorage` como más simple para el estado actual del proyecto, dejando la limitación documentada en el propio código en vez de ignorarla.

**Contraste con mobile:** Flutter (`mobile/lib/core/auth/token_storage.dart`, commit `64dae2e`) guarda el JWT en `flutter_secure_storage` (Keychain/Keystore real), no en texto plano — una postura de seguridad más fuerte que la web. Esta asimetría entre plataformas es intencional (cada plataforma usó el mecanismo de storage seguro disponible más simple), no un descuido: si se refuerza la seguridad de auth en el futuro, la prioridad es la web (localStorage es el eslabón más débil), no mobile.

## Decisión 16: Fix — `dni` opcional en el registro del consumer

**Fecha:** 2026-09-09
**Estado:** Aceptada (fix, implementa `design.md` Decisión 1)

**Decisión:** `Consumer#dni` pasó de `presence: true, uniqueness: true` a `uniqueness: true, allow_nil: true`; se agregó una migración para sacar el `NOT NULL` de `dni_encrypted`/`dni_bidx` a nivel de base de datos. Commit `1cdb20e`.

**Por qué:** El registro (`POST /api/v1/registrations`) sin `dni` devolvía 422 siempre, lo cual contradecía directamente `design.md` Decisión 1: el DNI lo carga el mozo en el local al cerrar la cuenta, no el consumer al autoregistrarse en la app. Era un bug de implementación que dejaba sin efecto una decisión de negocio ya tomada y documentada. Se confirmó con `BlindIndex.generate_bidx(nil) == nil`, y que el índice único de `dni_bidx` es no-parcial (Postgres trata cada `NULL` como distinto para uniqueness, así que múltiples consumers sin DNI no colisionan).

**Gap dejado fuera de alcance a propósito:** no existe todavía un endpoint para que un mozo cargue/actualice el `dni` de un consumer después del registro (no hay recurso `consumers`/`me` en `routes.rb`). Es una limitación aceptada del MVP, misma categoría que otras ya documentadas en `VisitsController`.

## Decisión 17: Patrón de facade mock↔real — desarrollo sin bloquear en el backend

**Fecha:** 2026-09-08/09
**Estado:** Aceptada, patrón establecido en ambas plataformas cliente

**Decisión:**
- **Web:** `web/lib/data/{merchants,menu-items,business-hours,search}.ts` — cada función chequea una vez `NEXT_PUBLIC_API_BASE_URL` (`isApiConfigured()`) y elige entre `lib/mock` o la implementación real de `lib/api`. Los callers (páginas/componentes) no necesitan saber cuál respondió. Sin la env var seteada, resuelve siempre a mock de forma síncrona (comportamiento sin cambios). Commit `d446ec5`.
- **Mobile:** equivalente vía `CONNECTION_MODE` (`String.fromEnvironment`, default `local`) en `mobile/lib/data/connection_mode.dart` + `providers.dart`, que switchea `dataSourceProvider` entre `LocalDataSource` (fixtures en `mobile/assets/fixtures/*.json`) y `RemoteDataSource` (Dio contra el backend real), ambas implementando la misma interfaz abstracta `DataSource`. Commit `64dae2e`.

**Por qué:** Permite construir y probar UI en cualquiera de las dos plataformas cliente sin depender de que el backend esté corriendo o tenga el endpoint específico terminado — el swap de mock a real es una sola variable de entorno, no un rewrite. Esto fue clave para poder paralelizar decenas de subagentes trabajando en pantallas distintas de forma simultánea durante la sesión, sin bloquearse entre sí esperando que el backend avanzara. El "real" fixture shape en mobile ya coincide con `backend/db/structure.sql` desde el diseño original (ver `docs/design-brief.md`), así que el swap es literalmente de una línea.

## Decisión 18: 3 lecciones de git en working tree compartido (sin worktrees aislados)

**Fecha:** 2026-09-08/09
**Estado:** Aceptada — reglas operativas nuevas para cualquier sesión futura con subagentes en paralelo

**Contexto:** Toda la sesión corrió con decenas de subagentes en paralelo trabajando directo sobre `main`, en un único working tree compartido, sin `isolation: worktree` por agente. Esto generó 3 incidentes reales, todos resueltos sin pérdida de datos, que se convirtieron en reglas:

1. **Nunca `isolation: worktree` para agentes paralelos en este proyecto.** Un worktree separado corriendo su propio `docker compose up` sin nombre de proyecto explícito colisiona: el nombre de proyecto default de Docker Compose es el basename del directorio (`backend` en cualquier worktree), así que un `docker compose` viejo de OTRO checkout puede quedar bind-mounteado y servir código desactualizado en el mismo puerto (`:3000`), confundiendo a cualquier sesión que asuma que está pegándole al backend correcto (incidente real documentado en `docs/backend-fase3-progress-log.md`, sección "Ports"). La sesión completa optó por trabajar directo en `main` sin worktrees para evitar esta clase de problema por completo.

2. **Nunca `git stash` en un working tree compartido.** Un `git stash` accidental de un agente se llevó puesto el trabajo en curso de 3 tareas paralelas de otros agentes. Detectado por los propios agentes afectados, restaurado con `git stash pop` controlado + un merge manual en un archivo tocado por dos tareas en momentos distintos. Nada se perdió, pero fue puro trabajo de recuperación evitable (documentado en `NEXT_STEPS_CONTEXT.md`).

3. **Nunca `git commit` sin pathspec (nunca `git add .` / `git commit -a`) en un working tree compartido.** Hubo 2 incidentes de concurrencia donde un commit sin pathspec explícito se llevó puesto cambios de otra tarea en curso en el mismo working tree. Autoresueltos por los propios agentes sin pérdida de datos, pero la regla que quedó es: **siempre `git add <archivos específicos>`** para aislar qué entra en cada commit cuando hay más de un agente escribiendo al mismo tiempo.

**Por qué importa:** ninguno de los 3 incidentes perdió trabajo, pero los 3 eran evitables por completo siguiendo estas reglas desde el principio — el patrón de coordinación por mensaje entre agentes (avisar qué archivos se van a tocar) funcionó, pero no reemplaza aislar los comandos de git que puedan pisar el working tree de otro agente.

## Decisión 19: Decisiones de producto explícitas del dueño que pisan al `.dc.html` original

**Fecha:** 2026-09-09
**Estado:** Aceptada — pedido explícito posterior al diseño original, con imágenes de referencia reales

**Decisión:** Durante una ronda de correcciones visuales pedida por el dueño del producto (con capturas/imágenes de referencia reales aportadas por él, no interpretación del `.dc.html`), se aplicaron estos cambios sobre el nav inferior de la web:

- **Nav plano, sin QR elevado:** se sacó el tratamiento de FAB circular elevado que tenía el botón de QR en `PhoneNav.tsx` (que en un momento previo de la sesión se había dejado a propósito, documentado como réplica de `extendBody: true` del shell de Flutter) — los 5 ítems del nav quedan al mismo nivel, sin elevación. Commit `5e0fbd3`.
- **5to ítem (Perfil/login) siempre visible, sin sesión:** en vez de que el ítem de perfil desaparezca del nav cuando no hay sesión iniciada, ahora siempre está presente y cambia a un prompt de login (ícono + ruta `/login`) cuando el usuario no está autenticado. Mismo commit.

**Por qué:** Fue un pedido explícito del dueño del producto en una ronda de correcciones visuales en vivo (`NEXT_STEPS_CONTEXT.md`, "Ronda de correcciones visuales pedidas por el usuario"), no un bug encontrado contra el `.dc.html`. Documentado acá como decisión de producto real (no como fix de fidelidad al diseño) para que quien mire el `.dc.html` original y note la diferencia entienda que es intencional y viene de un pedido posterior, no de una desviación accidental de implementación.

**Otro cambio de producto en la misma categoría:** Home se simplificó a **hero-only, centrado**, sacando la sección "Lugares destacados" (`FeaturedGrid`) que sí estaba en el diseño original — commit `cfcf166`. Mismo criterio: decisión de producto posterior al diseño base, no una regresión.

## Decisión 20: Toggle Lugares/Platos (búsqueda cross-merchant de platos) — feature agregada en ambas plataformas

**Fecha:** 2026-09-08/09
**Estado:** Aceptada, implementada en Next.js y llevada a paridad en Flutter

**Decisión:** Se agregó un modo de resultados de búsqueda por **plato** (cross-merchant, no solo por restaurante) en Buscar, con un toggle "Lugares"/"Platos". En Flutter, esto reemplazó un placeholder explícito (`_PlatosCategory` en `filters_sheet.dart` decía literalmente "Filtro de platos disponible desde la vista de platos" como texto de feature no implementada) por una vista real (`DishResultsList`, `dish_results_list.dart`) contra `RemoteDataSource.getAllMenuItems()`.

**Por qué:** El endpoint de búsqueda de menu items ya existía en el backend real; la brecha era solo de cliente. Se priorizó llevar Flutter a paridad exacta con lo ya construido en Next.js (`ResultModeToggle.tsx`, `DishCard.tsx`) en vez de dejar mobile un ciclo por detrás — documentado en `docs/flutter-vs-nextjs-gap-report.md`, Tarea 3.

## Decisión 21: Pin card del mapa (`MerchantMapCard`) por encima del nav — elevar el layer entero, no portalear la card

**Fecha:** 2026-09-09
**Estado:** Aceptada, implementada (commit `1b305e4`)

**Decisión:** `MerchantMapCard` se renderiza dentro de un `<Popup>` de `react-leaflet`, a su vez dentro del layer de mapa full-screen de `MapToggleSection.tsx` (`position: fixed`, con su propia clase `z-*`). Ese `position: fixed` + `z-index` explícito crea un **stacking context propio**: ningún z-index de lo que hay adentro (el popup de Leaflet incluido, que topea alrededor de z-index 700 internamente) puede pintar nunca por encima de un hermano de afuera con z-index mayor — como `PhoneNav` (`z-30`) — sin importar qué tan alto sea ese z-index interno. Confirmado en vivo con `orca eval`: el layer del mapa reportaba `z-index:20` de forma fija y el pin card quedaba siempre tapado por el nav flotante.

La solución elegida fue: `LeafletMap` reporta `popupopen`/`popupclose` (vía un `useMapEvents` watcher chico) hacia arriba a través de `MapPanel` hasta `MapToggleSection`, que sube el z-index de **todo el wrapper fixed del mapa** (no solo la card) a `z-[100]` mientras hay una card abierta, y lo vuelve a `z-20` al cerrarla.

**Alternativas descartadas:**
- **Portalear solo la card (`ReactDOM.createPortal` a `document.body`)**, dejando el resto del mapa en su z-20 normal. Es la solución "más limpia" en teoría (no eleva nada más que la card), pero exige reimplementar a mano el posicionamiento que Leaflet ya calcula internamente para el popup (`popupAnchor`, autoPan, seguimiento del marcador al hacer pan/zoom) — desproporcionado para el alcance de este fix.
- **Subir el z-index del wrapper del mapa de forma permanente** (no solo mientras la card está abierta). Se descartó: taparía el nav todo el tiempo que el mapa esté activo, no solo cuando hay una card abierta — contradice el comentario de diseño explícito en `use-map-mode.ts` de que "el mapa nunca debe tapar el nav" (que ahí se refiere a que el scroll-hide del nav no debe dispararse durante el pan del mapa, un problema distinto pero relacionado).

**Por qué importa para quien toque el mapa de nuevo:** cualquier otro elemento flotante nuevo que se agregue dentro del layer `fixed` de `MapToggleSection` (chips, botones, etc.) va a tener el mismo techo — ningún z-index interno lo va a sacar de ahí sin repetir este mismo patrón (levantar el wrapper entero condicionalmente) o portalear afuera del árbol.

## Decisión 22: Gotcha adicional sobre `git commit -- <pathspec>` en working tree compartido (refina Decisión 18.3)

**Fecha:** 2026-09-09
**Estado:** Aceptada — refinamiento de una regla ya vigente

**Contexto:** Durante la misma sesión larga (ver Decisión 18), un fix de `/buscar` (sacar el `<Header />` mobile, ver commit `e8385e8`) quedó sin comitear por un rato mientras otro agente trabajaba en paralelo sobre archivos distintos del mismo working tree. Ese otro agente corrió `git commit -- web/app/buscar/page.tsx <otros paths>` con pathspec explícito (siguiendo la regla de Decisión 18.3) para comitear SU propio cambio en ese mismo archivo — pero `git commit -- <pathspec>` re-stagea esos paths **desde el working tree**, no desde un índice pre-armado. Si el índice para ese archivo ya tenía algo parcial stageado a mano (ej. vía `git apply --cached` para excluir a propósito un cambio ajeno todavía sin comitear), ese staging parcial se pisa silenciosamente por el contenido completo del working tree — el `<Header />` sin comitear de la otra tarea viajó adentro de un commit con un mensaje que no lo mencionaba. Se detectó, se revirtió pensando que era screen accidental ("scope-leak"), y tuvo que volver a aplicarse una vez aclarado que era intencional (commits `ae8f8ac` → `b44087d` → `e8385e8`).

**Regla que queda, más específica que Decisión 18.3:** `git add <pathspec>` + `git commit` (dos pasos, sin `--` de pathspec en el commit) es más seguro que `git commit -- <pathspec>` cuando puede haber staging parcial en juego, porque separa explícitamente "qué quedó en el índice" de "qué hay en el working tree" — y agiliza notar un diff inesperado con `git diff --cached` antes de comitear. Y sobre todo: **no dejar cambios sin comitear por más de unos minutos en un working tree compartido**, incluso si son de un archivo que "nadie más está tocando" — otro agente puede tocar ese mismo archivo por una razón no relacionada y arrastrar el cambio ajeno sin querer.

## Decisión 23: Skeletons de `loadingMore` en el grid de escritorio (`SearchResultsGrid.tsx`) — leer `gridTemplateColumns` calculado en vez de recalcular columnas a mano

**Fecha:** 2026-09-09
**Estado:** Aceptada, implementada

**Decisión:** El grid de resultados en desktop usa `grid-cols-[repeat(auto-fit,minmax(260px,1fr))]` — la cantidad real de columnas es responsive y depende del ancho disponible, no es un número fijo conocido en JS. Para que los skeletons del `loadingMore` completen la fila incompleta (en vez de arrancar una fila nueva fija de 3, que era el bug original), la cantidad de columnas se lee directamente del browser post-layout: `getComputedStyle(gridEl).gridTemplateColumns.split(" ").length`, sobre un `ResizeObserver` en el contenedor del grid (no un listener de `resize` en `window`, porque también hay que reaccionar a cambios de layout que no disparan ese evento, p. ej. el sidebar de filtros). Con esa columna real se calcula `remainder = visibleCount % columns` y se renderizan exactamente `columns - remainder` (o `columns` si `remainder === 0`) placeholders, como **hermanos DOM de las cards reales dentro del mismo contenedor grid** (no en un `<div>` de grid separado debajo) — así el auto-placement de CSS Grid completa solo el hueco de la última fila antes de bajar a la próxima, sin que el componente tenga que decidir a mano dónde termina cada fila.

**Por qué `getComputedStyle` y no recalcular a mano:** replicar el algoritmo de `auto-fit`/`minmax` a mano (ancho del contenedor ÷ ancho de ítem + gap, con redondeo) es una segunda implementación del mismo cálculo que el browser ya resuelve de forma exacta y gratis, y que se desincroniza en los bordes (scrollbar, `box-sizing`, breakpoints intermedios no contemplados). Leer el resultado ya resuelto del layout evita esa duplicación y es la única forma de tener el número de columnas *real*, no aproximado.

**Confirmado con Playwright/CDP (1440×900, `/buscar`):** con 3 columnas reales y 10 cards visibles (`10 % 3 = 1`), aparecieron exactamente 2 skeletons a la derecha de la última card; con 2 columnas reales (viewport 1120px) y 10 cards (`10 % 2 = 0`), aparecieron exactamente 2 skeletons formando una fila nueva completa. El comportamiento de phone (`RowSkeleton`, contenedor flex separado, cantidad fija de 3) no se tocó.

## Decisión 24: Gotcha CSS — `aspect-ratio` en un ítem flex necesita `overflow-hidden` propio, no alcanza con el del contenedor (`MerchantCard.tsx`, layout `card`)

**Fecha:** 2026-09-09
**Estado:** Aceptada, implementada (commit `3703399`)

**Bug reportado:** en `/buscar` desktop, las cards de merchant del grid renderizaban con alturas inconsistentes — algunas visiblemente más altas que sus hermanas en la misma fila, según la relación de aspecto natural de la foto de portada (una foto vertical-ish de comida rompía la altura de toda la card).

**Causa real (no la esperada):** el wrapper de la imagen (`<Link>` con `aspect-[16/10] w-full`) ya tenía la relación de aspecto fija desde el primer commit de esta card (`eab9471`) — no era un `aspect-ratio`/`object-cover` faltante como parecía a simple vista, y confirmado con Playwright las cards de una misma fila SÍ tenían la misma altura entre sí; el problema era fila-a-fila. La causa real: `Card` (el `<article>` contenedor) es `flex flex-col`, y ese `<Link>` es su ítem flex directo. Un ítem flex sin `min-height` explícito tiene por spec un **`min-height: auto`** que, cuando el ítem contiene un elemento reemplazado (el `<img>`, dimensionado con `h-full w-full` en porcentaje) y su propio `overflow` es `visible`, resuelve al tamaño mínimo de contenido — que para una foto usa la relación de aspecto **natural** de la imagen, no la declarada por `aspect-ratio`. Si esa altura de contenido (derivada de la imagen natural) superaba la altura calculada por `aspect-[16/10]`, el layout de flexbox estiraba el ítem (y la card entera) para acomodarla. Confirmado con Playwright midiendo el wrapper de la imagen directamente: una foto de `1200×1800` (portrait) medía `304×455px` en vez de los `304×190px` esperados por `16/10`, mientras que fotos landscape (`1200×800`) medían `304×202px` — todas midiendo, en la práctica, la altura que les daría su propia relación de aspecto natural a ese ancho, como si `aspect-ratio` no existiera.

`Card` ya tiene `overflow-hidden` en su propio className, pero eso solo recorta visualmente *después* de que el `<Link>` ya creció más allá de su caja — el `overflow` que importa para el cálculo de `min-height: auto` de un ítem flex es el del ítem mismo, no el de un ancestro.

**Fix:** agregar `overflow-hidden` al `<Link>` (el wrapper de la imagen), no solo al `<Card>`. Por spec, cuando el `overflow` de un ítem flex no es `visible`, su `min-height: auto` resuelve a `0` en vez de al tamaño mínimo de contenido — con eso `aspect-[16/10]` + `object-cover` vuelven a ser los únicos que deciden el tamaño de la caja, sin importar las dimensiones naturales de la foto. Un diff de una sola línea.

**Por qué no era una regresión:** se revisó `git log -p` de `MerchantCard.tsx` completo — la línea `aspect-[16/10]` nunca tuvo `overflow-hidden` propio desde el commit original que creó esta card; el layout `row` (mobile, caja fija `h-[88px] w-[88px]`) sí tuvo `overflow-hidden` desde siempre porque no depende de `aspect-ratio`. Era un bug latente desde el día uno, recién visible con datos mock que incluyeran una foto de relación de aspecto marcadamente distinta a 16:10 — no un fix anterior que se haya roto.

**Confirmado contra el diseño de referencia:** `docs/design-reference/Fudo Customers.dc.html` (línea 353-355, el card real de `places`, no el skeleton) usa el mismo patrón — imagen con `position: relative; aspect-ratio: 16/10` — pero el card contenedor ahí es HTML/CSS plano (`div` en flujo normal, sin `display: flex`), así que el bug de `min-height: auto` de flexbox nunca aparece en la referencia; solo se manifestó al traducir ese layout a un `Card` con `flex flex-col` en React.

**Por qué importa para quien toque más cards con imágenes de tamaño fijo:** cualquier caja con `aspect-ratio` + un `<img>`/elemento reemplazado adentro, si es (o puede llegar a ser) ítem directo de un contenedor `flex` o `grid`, necesita su propio `overflow-hidden` (o `min-h-0` explícito) — no alcanza con que el contenedor tenga `overflow-hidden`. Vale también para `MerchantMapCard` y cualquier otra card nueva que reutilice este patrón de imagen recortada.

## Nota operativa: colisión de puertos entre worktrees de Docker Compose

**Fecha:** 2026-09-08
**Estado:** Resuelta, generalizada como regla en Decisión 18.1

Un `docker compose up` sin `-p <nombre>` explícito usa el basename del directorio como nombre de proyecto — colisiona entre worktrees distintos que comparten el mismo nombre de subcarpeta (`backend/` en todos). Esto hizo que una sesión de mobile/web pegara contra un backend viejo (Fase 0/1, sin `/api/v1`) sin darse cuenta, porque el contenedor viejo de OTRO worktree seguía respondiendo en `:3000`. Documentado en detalle en `docs/backend-fase3-progress-log.md`. Regla: siempre `docker compose -p <worktree-o-proyecto>` si en algún momento se vuelve a trabajar con más de un checkout del repo al mismo tiempo.

## Decisión 25: Pill de horarios ahora es un accordion real que colapsa/expande "Horarios" — pisa la Decisión previa de "siempre expandido" y el default difiere del `.dc.html`

**Fecha:** 2026-09-09
**Estado:** Aceptada, implementada (`MerchantDetailView.tsx`)

**Contexto:** `MerchantDetailView.tsx` tenía documentado explícitamente (comentario de cabecera del componente) que la lista semanal de horarios se renderizaba siempre expandida a propósito, en ambos layouts, "since this is static SSG output with no client state to back a toggle" — y el chevron de la pill de arriba ("Cerrado"/"Abierto ahora") solo hacía scroll hacia la sección "Horarios" de más abajo, sin colapsarla. El dueño de producto reportó esto como bug con una captura real: la pill parece un trigger de expand/collapse (tiene chevron) pero no correlaciona con la sección de abajo, que siempre se muestra completa.

**Decisión:** Se conectó la pill como trigger real de un accordion: un solo estado compartido (`hoursOpen`, derivado de `manualOpen ?? !isPhone` en `MerchantDetailView.tsx`) controla tanto la dirección del chevron (`expand_more`/`expand_less`) como si la sección "Horarios" completa (heading + tabla semanal) se renderiza o no. Mismo patrón `hoursOpen`/`toggleHours`/`hours.chevron` que **ya estaba especificado en ambos `.dc.html`** (`Fudo App.dc.html` y `Fudo Customers.dc.html`, buscar `toggleHours`) — la implementación previa se había desviado deliberadamente del diseño de referencia en este punto, y este pedido del dueño de producto la vuelve a alinear.

**Diferencia real con el `.dc.html`, explícita a propósito:** en ambos archivos de referencia, el estado inicial mockeado es `hoursOpen: false` sin importar el viewport (un solo objeto `state`, sin rama por ancho de pantalla). El dueño de producto pidió explícitamente que el default dependa del viewport: **abierto por defecto en desktop (>=900px)**, **cerrado por defecto en mobile (<900px)**. Esto no es una interpretación de la referencia — es un requisito de producto posterior, explícito, que prevalece sobre el default estático del prototipo (mismo criterio que la Decisión 19: pedidos explícitos del dueño con evidencia real pisan al `.dc.html` original cuando divergen).

**Cómo se resolvió el default dependiente de viewport sin quedar obsoleto tras la hidratación:** `useIsPhoneViewport()` (`lib/hooks/use-viewport.ts`) devuelve `false` (wide) como snapshot de servidor/primer paint — es la "wide es el guess más seguro" ya documentada en ese hook. Un `useState(() => !isPhone)` con inicializador perezoso solo se ejecuta una vez, en el primer render; si ese primer render todavía ve `isPhone=false` (el snapshot de servidor) y el visitante está en un viewport real de celular, el re-render de corrección de hidratación de `useSyncExternalStore` no vuelve a ejecutar el inicializador — `hoursOpen` quedaría congelado en `true` incluso en mobile. Se resolvió derivando `hoursOpen` en cada render como `manualOpen ?? !isPhone`, con `manualOpen` en `null` hasta el primer toggle manual del visitante: mientras es `null`, el valor mostrado seguí a `isPhone` en tiempo real (así se autocorrige con la hidratación); apenas el visitante togglea una vez, `manualOpen` fija el valor y ya no vuelve a seguir cambios de viewport. No hay precedente de este patrón exacto en el resto del código (`use-map-mode.ts` y otros usos de `useSyncExternalStore` en este repo no derivan un estado inicial condicional de esta forma), así que queda documentado acá para quien necesite el mismo patrón ("default por viewport que se puede overridear a mano una sola vez") en otro componente.

**Por qué no se restructuró para calzar 1:1 con el `.dc.html`:** en la referencia, la tabla semanal vive anidada *dentro* de la misma card que la pill (un solo contenedor con borde), sin un heading "HORARIOS" separado. La implementación actual tiene dos piezas visuales distintas (la pill como su propia card, y una sección "Horarios" con heading propio más abajo) — así es como el dueño de producto describió el bug y el estado deseado ("la pill de arriba expande/colapsa la sección HORARIOS de abajo"), no pidió fusionar las dos cards en una. Se mantuvo la estructura visual de dos piezas ya existente y solo se conectó el estado — cambiar el layout a una sola card hubiese sido una reestructuración visual no pedida.

## Decisión 26: `POST /api/v1/search` requería auth por accidente de diseño — la Decisión "access model" de la Decisión de autenticación (commit `8bdbbc0`) metió la pata al agrupar Search con los endpoints privados

**Fecha:** 2026-09-09
**Estado:** Aceptada, implementada (fix de bug reportado en vivo por el dueño de producto)

**Bug reportado:** el prompt de búsqueda por IA del Home devolvía **401 Unauthorized** en la consola/network tab, para cualquier visitante no logueado. Reproducido real con Playwright headless (logueado afuera, `localStorage` limpio): `POST http://localhost:3000/api/v1/search` -> 401 `{"error":"Not authenticated"}`.

**Causa real:** `Api::V1::SearchController` tenía `before_action :authenticate_consumer!` desde el commit `8bdbbc0` ("feat(/backend): add JWT authentication and API rate limiting"), que documentaba explícitamente en su propio mensaje de commit la decisión de dejar `POST /api/v1/search` "fully authenticated" junto con visits/favorites/gifts/etc. — **no fue un accidente de una sola línea ni una regresión de un commit posterior** (se descartó la hipótesis inicial de que los commits `72bdc16`/`ae8f8ac`, de una tarea sobre "coordinate tags/Gemini schema", hubieran tocado esto — no lo tocaron). Fue una decisión de diseño real, tomada y documentada a propósito, que resultó estar **mal** frente a la regla de negocio real: "la busqueda por IA y /buscar es gratis, lo unico q necesita permisos es ver el perfil o regalar o ver los datos de cuantas veces fui a un restaurante" (dicho en vivo por el dueño de producto). El spec de request (`spec/requests/api/v1/search_spec.rb`) y el spec de OpenAPI/rswag (`spec/integration/api/v1/search_spec.rb`) incluso tenían un test explícito `"returns 401 without authentication"` cubriendo ese comportamiento — o sea, el comportamiento "malo" estaba testeado y verde, no era un bug no detectado.

**Fix:** se sacó el `before_action :authenticate_consumer!` de `SearchController` (`backend/app/controllers/api/v1/search_controller.rb`), siguiendo el mismo patrón que ya usan los demás endpoints públicos-para-lectura de este código (`before_action :authenticate_consumer!, except: %i[index show]` en `merchants_controller.rb`/`tags_controller.rb`/etc.) — acá simplificado a "sin auth en absoluto" porque `SearchController` solo tiene la acción `create` y es 100% pública. `SearchHistory#consumer_id` es `NOT NULL` (`belongs_to :consumer` requerido), así que `build_search_history` ahora devuelve `nil` cuando no hay `current_consumer` y el `create` no persiste ningún `SearchHistory` para un visitante anónimo — cuando SÍ hay un bearer token válido (un consumer ya logueado usando el buscador), el comportamiento de atribución a su historial sigue exactamente igual que antes.

**Por qué no era un bug de frontend:** se investigó `web/lib/api/search.ts` como candidato (el enunciado del bug sugería que quizás mandaba un header `Authorization` viejo/inválido) — pero `authHeader()` (`web/lib/auth/token-storage.ts`) devuelve `{}` cuando no hay token guardado, no manda ningún header malformado. El 401 era 100% responsabilidad del backend.

**Alternativas descartadas:** hacer `consumer_id` nullable en `search_history` para trackear también búsquedas anónimas. Se descartó por alcance — el pedido del dueño de producto fue "que no requiera login", no "que también trackeemos anónimos"; ampliar el modelo de datos para eso es una decisión de producto separada, no parte de este fix.

## Decisión 27: `AiSearchResolver.tsx` se quedaba trabado en el skeleton para siempre en dev — el guard anti-doble-llamada de StrictMode también bloqueaba el `.then`/`.catch` de la llamada real

**Fecha:** 2026-09-09
**Estado:** Aceptada, implementada

**Bug reportado (segundo síntoma del mismo incidente):** navegar directo a `/buscar?ai=cafeterias` colgaba mostrando el skeleton indefinidamente (1+ minuto sin resolver), incluso después de arreglado el 401 de la Decisión 26. Confirmado con Playwright real: el `POST /api/v1/search` completaba con **200** (visible en el network log), pero la URL nunca dejaba de tener `?ai=cafeterias` y ningún `history.replaceState`/`pushState` nuevo se disparaba — el componente quedaba renderizando `<BuscarSkeleton />` para siempre.

**Causa real:** el `useEffect` de `AiSearchResolver.tsx` usaba un solo `startedRef` para dos cosas a la vez: (1) evitar que la llamada real a Gemini (no idempotente, facturada) se disparase dos veces por el doble-invoke de efectos de React StrictMode en dev (mount → cleanup sincrónico → mount de nuevo), y (2) —sin querer— también servía de guard para *adjuntar* los handlers `.then`/`.catch`. La segunda ejecución del efecto (la que sobrevive, la "real") entraba al `if (startedRef.current) return;` y salía inmediatamente, sin registrar ni un nuevo `cancelled` ni nuevos handlers. Mientras tanto, la PRIMERA ejecución del efecto (la que StrictMode descarta) sí había disparado el fetch real y adjuntado su propio `.then`/`.catch` — pero su función de cleanup corre de inmediato (as part del doble-invoke sintético) y pone `cancelled = true` en ese closure. Cuando el fetch real finalmente resuelve (con 200), el `.then` de esa primera ejecución ve `cancelled === true` y hace `return` sin llamar a `router.replace(...)`. Resultado neto: la llamada de red se ve exitosa en el Network tab, pero nadie navega a ningún lado — exactamente lo reportado.

**Fix:** separar las dos responsabilidades. `startedRef` sigue existiendo y sigue disparando `resolveAiSearchFilters(query)` una sola vez — pero ahora la promesa en curso se guarda en un ref propio (`resultPromiseRef`), y **cada** ejecución del efecto (incluida la que sobrevive al doble-invoke) adjunta su propio `.then`/`.catch` con su propio `cancelled` local sobre esa misma promesa compartida. Así la llamada a Gemini se sigue disparando una sola vez (no se rompe el motivo original del guard), pero la ejecución del efecto que realmente queda montada sí llega a procesar el resultado y navegar.

**Por qué no se agregó una pantalla de error dedicada:** se evaluó agregar un estado de error visible (con botón de reintentar/volver) para el caso general de que la búsqueda falle o tarde — pero el flujo ya tenía manejo de fallas razonable sin necesitar una pantalla nueva: `apiFetch` (`web/lib/api/client.ts`) ya aborta con timeout a los 5s (`REQUEST_TIMEOUT_MS`), y el `.catch` de `AiSearchResolver` ya degrada con gracia a una búsqueda de texto plano (`router.replace` a `/buscar?q=<mismo texto>`) en vez de dejar al visitante colgado — un resultado de búsqueda por nombre es un resultado completo y útil, no un callejón sin salida. Se revisó `docs/design-reference/Fudo App.dc.html` buscando un patrón de pantalla de error para búsqueda fallida y no existe ninguno para este caso. Agregar una pantalla nueva sin patrón de referencia y sin necesidad real (el degrade-a-búsqueda-simple ya cumple "nunca dejar al visitante mirando un skeleton infinito" una vez arreglado el bug de arriba) hubiese sido scope no pedido.

## Decisión 28: Gotcha de tooling — correr `bundle exec rspec` dentro del contenedor Docker de `development` corre en el entorno equivocado si no se fuerza `RAILS_ENV=test`

**Fecha:** 2026-09-09
**Estado:** Aceptada — gotcha documentado, no requirió cambio de código

**Síntoma:** al verificar el fix de la Decisión 26 corriendo `docker compose exec -T web bundle exec rspec spec/requests/api/v1/search_spec.rb`, **todos** los specs de request fallaban con `403 Forbidden` — incluidos specs de endpoints públicos sin tocar en esta tarea (`merchants_spec.rb`, `"requires no authentication — merchant discovery is public"`). El body de la respuesta era la página de error nativa de Rails `ActionDispatch::HostAuthorization`: `"Blocked hosts: www.example.com"` (el host default que usa el cliente de test de `rspec-rails` en sus requests).

**Causa real:** el contenedor `backend-web-1` corre con `RAILS_ENV=development` seteado por `docker-compose.yml`. `spec/rails_helper.rb` (generado por Rails, no tocado en este repo) hace `ENV["RAILS_ENV"] ||= "test"` — el `||=` no pisa un valor ya seteado, así que **rspec corría contra el entorno `development`**, no `test`. `config.hosts` en `development` trae por default `[".localhost", ".test", IPAddr 0.0.0.0/0, IPAddr ::/0]` (vacío en `test`, sin restricción) — ninguno de esos patterns matchea `www.example.com`, el host default de los request specs, así que `ActionDispatch::HostAuthorization` bloqueaba el 100% de las requests con 403 antes de que llegaran a ningún controller. Confirmado imprimiendo `Rails.application.config.hosts` desde dentro de un spec real (development defaults) vs. desde `bin/rails runner` con `RAILS_ENV=test` explícito (`[]`, vacío).

**No es una regresión de esta tarea ni de ninguna otra reciente** — es un gotcha del entorno Docker de este repo en sí, expuesto recién ahora porque es la primera vez en esta sesión que se corrió `bundle exec rspec` a mano dentro de `docker compose exec web` en vez de vía CI o `docker compose run` (que sí podría tener `RAILS_ENV` distinto). Se confirmó forzando `RAILS_ENV=test` explícito (`docker compose exec -T -e RAILS_ENV=test web bundle exec rspec`): con eso, la suite completa (402 examples) corre y pasa en verde.

**Regla que queda para quien corra tests dentro de este contenedor de dev:** siempre `docker compose exec -T -e RAILS_ENV=test web bundle exec rspec ...` (o exportar `RAILS_ENV=test` en el shell del `exec`) — nunca asumir que el contenedor de `docker compose up` normal corre los tests en el entorno correcto solo porque `rails_helper.rb` "ya se encarga". No se tocó `docker-compose.yml` ni `rails_helper.rb` para forzar esto porque cambiar el `RAILS_ENV` default del contenedor rompería el flujo normal de `rails server` en dev, y agregar un `ENV["RAILS_ENV"] = "test"` (sin `||=`) a `rails_helper.rb` para "arreglarlo" del lado del repo escondería el mismo problema para cualquiera que corra rspec fuera de Docker con un `RAILS_ENV` real distinto seteado a propósito (ej. una entorno de staging local) — mejor un hábito documentado que una sobre-corrección silenciosa en un archivo generado por el framework.
