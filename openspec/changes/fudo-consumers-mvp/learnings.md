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

## Nota operativa: colisión de puertos entre worktrees de Docker Compose

**Fecha:** 2026-09-08
**Estado:** Resuelta, generalizada como regla en Decisión 18.1

Un `docker compose up` sin `-p <nombre>` explícito usa el basename del directorio como nombre de proyecto — colisiona entre worktrees distintos que comparten el mismo nombre de subcarpeta (`backend/` en todos). Esto hizo que una sesión de mobile/web pegara contra un backend viejo (Fase 0/1, sin `/api/v1`) sin darse cuenta, porque el contenedor viejo de OTRO worktree seguía respondiendo en `:3000`. Documentado en detalle en `docs/backend-fase3-progress-log.md`. Regla: siempre `docker compose -p <worktree-o-proyecto>` si en algún momento se vuelve a trabajar con más de un checkout del repo al mismo tiempo.
