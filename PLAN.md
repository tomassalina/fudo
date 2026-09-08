# PLAN.md — Fudo Consumers

Plan técnico de construcción para la demo, en 6 fases. Contexto de negocio y decisiones de producto: `PRD.md`. Fuente de verdad ejecutable del modelo de datos: `backend/db/structure.sql` (14 tablas + 7 enums) y su diagrama en `docs/database-schema.drawio` / `docs/database-schema.png`.

## Cómo correr esto en paralelo (worktrees de git)

Cada track de trabajo vive en su propio `git worktree`, con su propia rama, para poder avanzar varias fases al mismo tiempo sin pisarse:

| Worktree | Rama | Contenido |
|---|---|---|
| `fudo-backend` | `feat/backend` | Rails API + PostgreSQL + Docker Compose (Fases 0, 1, 3) |
| `fudo-mobile` | `feat/mobile` | App Flutter (Fases 0, 2, 4) |
| `fudo-web` | `feat/web` | Next.js (Fases 0, 2, 4 — menor prioridad) |

Grafo de dependencias real (no es 100% lineal aunque la numeración lo parezca):

```
Fase 0 backend ──┐
Fase 0 mobile  ──┼── (ya en curso, 3 worktrees en paralelo, sin dependencias entre sí)
Fase 0 web     ──┘
       │
Fase 0 backend → Fase 1 (DB: migraciones + seeders, worktree fudo-backend)
       │
       ├──────────────────────────────┐
       ▼                               ▼
Fase 2 (Flutter + Next.js con     Fase 3 (Backend completo,
fixtures, worktrees mobile/web,   worktree fudo-backend)
EN PARALELO con Fase 3 —          — no depende de Fase 2
no depende del backend real)
       │                               │
       └──────────────┬────────────────┘
                       ▼
       Fase 4 (conectar mobile y web al backend real,
       en paralelo entre sí, pero solo puede arrancar
       cuando Fase 2 Y Fase 3 están listas)
                       │
                       ▼
       Fase 5 (E2E completo, secuencial, un solo track)
```

La clave: **Fase 2 y Fase 3 no se bloquean entre sí.** Fase 2 consume fixtures locales (no pega al backend), así que el track mobile/web puede seguir de largo mientras el track backend construye los endpoints reales. El único punto de sincronización real es la entrada a Fase 4.

Web es la prioridad más baja de las tres apps: si el tiempo se acorta, se sacrifica primero (se puede entregar la demo con solo mobile + backend funcionando).

---

## Fase 0 — Scaffold de todas las apps

**Estado: en curso**, en los 3 worktrees de arriba, en paralelo, sin dependencias entre sí.

### Backend (`fudo-backend`)
- **Entrega:** Rails en modo API (`rails new fudo_backend --api --database=postgresql`), PostgreSQL vía Docker Compose, boot local funcionando.
- **Archivos clave:** `Gemfile`, `config/application.rb` (`config.api_only = true`), `docker-compose.yml` (servicio `db` con Postgres, servicio `web` opcional), `config/database.yml`, `.env`/`config/master.key`.
- **Cómo se prueba:** `docker compose up`, `rails s`, `curl localhost:3000/up` responde 200 (healthcheck default de Rails 7+).
- **Qué no se hace:** ningún modelo, migración ni endpoint todavía — eso es Fase 1 y 3.

### Mobile (`fudo-mobile`)
- **Entrega:** proyecto Flutter inicializado (`flutter create`), estructura de carpetas por feature (`lib/features/search`, `lib/features/my_places`, `lib/features/gift`), navegación de 3 tabs con placeholders vacíos.
- **Archivos clave:** `pubspec.yaml`, `lib/main.dart`, `lib/app.dart` (bottom nav de 3 pestañas), `analysis_options.yaml`.
- **Cómo se prueba:** `flutter run` en simulador iOS/Android, la navegación entre las 3 pestañas anda.
- **Qué no se hace:** ningún diseño visual real todavía (ver nota de diseño en Fase 2), ninguna llamada a red.

### Web (`fudo-web`)
- **Entrega:** proyecto Next.js con App Router + TypeScript (`create-next-app --typescript --app`), página de búsqueda placeholder.
- **Archivos clave:** `app/layout.tsx`, `app/page.tsx`, `tsconfig.json`, `next.config.ts`.
- **Cómo se prueba:** `npm run dev`, la página placeholder carga en `localhost:3000`.
- **Qué no se hace:** SSR real, nada de datos — es la app de menor prioridad, se construye de última si sobra tiempo y no bloquea ninguna otra fase.

---

## Fase 1 — Base de datos: migraciones + seeders

**Worktree:** `fudo-backend`. Depende de Fase 0 backend.

- **Entrega:** migraciones de Rails que reproducen exactamente `backend/db/structure.sql` (mismos tipos, mismos enums nativos de Postgres, mismos índices), más `db/seeds.rb` con datos ficticios completos.
- **Archivos clave:** `db/migrate/*_create_*.rb` (una por tabla + una por cada `CREATE TYPE`), `db/structure.sql` (usar `config.active_record.schema_format = :sql` porque hay enums nativos — `schema.rb` no los representa bien), `db/seeds.rb`, `db/seeds/` (helpers separados por entidad si el seed crece mucho).
- **Datos a generar en el seeder:**
  - 30 `merchants` ficticios en Palermo, CABA — lat/long variados y realistas (jitter dentro del bounding box aprox. de Palermo, no todos en el mismo punto).
  - 150 `menu_items` con precios realistas en ARS (septiembre 2026) — usar rangos orientativos por sección (ej. café/bebida ~$3.500–$7.000, entrada ~$8.000–$14.000, plato principal ~$14.000–$30.000, postre ~$6.000–$10.000; son valores de referencia para el seeder, no un dato de inflación verificado).
  - 210 `business_hours` — importante: varios merchants con **doble turno el mismo día** (ej. 12:00–15:30 y 20:00–00:30), por eso el schema NO tiene índice único en `(merchant_id, day_of_week)`. El seeder debe generar explícitamente esas filas duplicadas por día para al menos un subconjunto de merchants (bares/restaurantes con corte de tarde).
  - 150 `loyalty_rules` con `visits_required` variado: mezclar 2, 4, 6, 8 y 10 entre los 30 merchants (varias reglas por merchant, incluyendo alguna `is_permanent: true` como beneficio de cliente fijo).
  - `tags` + `merchants_tags` + `menu_items_tags`.
  - 1 `consumer` de demo, con `dni_encrypted` y `dni_bidx` generados de verdad vía Lockbox (no hardcodeados en texto plano) — requiere que el modelo `Consumer` con `has_encrypted :dni` ya exista, así que el seeder corre las gemas de cifrado igual que en runtime real.
  - 27 `visit_summaries`, 116 `visits` (números coherentes: cada `visit` incrementa su `visit_summary` correspondiente — no generarlos de forma independiente).
  - Algunos `favorites` y `gifts` de ejemplo para que "Mis Lugares" y "Regalar" no arranquen vacíos en la demo.
- **Cómo se prueba:** `rails db:create db:migrate db:seed`, después `rails console` para chequear counts (`Merchant.count == 30`, `BusinessHour.where(merchant: m).count > 1` para al menos un merchant, etc.) y que `Consumer.first.dni_bidx` sea buscable (`Consumer.find_by(dni_bidx: Consumer.generate_dni_bidx(dni))` o el finder que exponga Lockbox).
- **Qué no se hace:** geocoding real contra un servicio externo (las coordenadas son generadas, no consultadas), timezone (todo vive en `America/Argentina/Buenos_Aires` implícito, no hay columna `timezone` en `merchants`).

---

## Fase 2 — Frontends con datos de ejemplo

**Worktrees:** `fudo-mobile` y `fudo-web`, en paralelo entre sí. Depende de Fase 1 (necesita la forma real de los datos) y de Fase 0 de cada app. **No depende de Fase 3** — corre en paralelo con el backend completo.

- **Entrega:** ambos frontends renderizando las 3 pantallas (mobile) / la búsqueda (web) con datos de ejemplo, sin pegarle a ningún backend real todavía.
- **Cómo se generan los fixtures:** un rake task en `fudo-backend` (`rake export:fixtures`) vuelca los datos ya sembrados en Fase 1 a JSON, respetando **exactamente** los nombres y tipos de columnas de `backend/db/structure.sql` (mismo shape que después va a devolver la API real). Esos JSON se copian a mano a cada frontend.
- **Archivos clave (mobile):** `assets/fixtures/*.json`, `lib/data/local/local_data_source.dart` implementando la misma interfaz abstracta que después va a implementar `remote_data_source.dart` (Fase 4) — el swap tiene que ser un cambio de una línea en el provider/DI, no un rewrite.
- **Archivos clave (web):** `lib/fixtures/*.json` o `app/_fixtures/`, un mock de la capa de datos (`lib/data/merchants.ts`) con la misma firma que el futuro `fetch` real.
- **Diseño visual (mobile):** el diseño ya está prototipado aparte en Claude Design, estilo Roomix — fondo oscuro, glow violeta, buscador como protagonista de la pantalla principal. **Queda pendiente de integrar** cuando el usuario comparta ese prototipo; mientras tanto Fase 2 entrega la funcionalidad con estilos base/placeholder, no el diseño final.
- **Cómo se prueba:** correr cada app apuntando a los fixtures y verificar visualmente que las 3 pestañas (mobile) y la búsqueda (web) muestran los 30 merchants, sus horarios con doble turno, y al menos un gift/favorite de ejemplo.
- **Qué no se hace:** ninguna llamada de red, ningún manejo de auth todavía, ningún estado que dependa de un servidor.

---

## Fase 3 — Backend completo

**Worktree:** `fudo-backend`. Depende de Fase 1. **No depende de Fase 2** — corre en paralelo con esa fase.

- **Entrega:** API REST versionada bajo `/api/v1/`, documentada con OpenAPI generado desde specs de RSpec vía `rswag`.
- **Endpoints mínimos:**
  - **Auth:** `POST /api/v1/registrations`, `POST /api/v1/sessions` (login) — email + password, `has_secure_password` (bcrypt), **sin Google OAuth** para este MVP. El login devuelve un token (JWT vía gema `jwt`, o token de sesión simple) que mobile/web guardan para las siguientes requests.
  - **Merchants / Menu items:** `GET /api/v1/merchants`, `GET /api/v1/merchants/:id`, `GET /api/v1/merchants/:id/menu_items` — **solo lectura** desde el cliente (el alta de merchants/menu_items no es parte de este producto, viene de otro sistema de Fudo).
  - **Búsqueda:** `POST /api/v1/search` — recibe texto libre (`{ query: "algo picante y barato en Palermo" }`), le pega a un service object (`Search::ParseAndMatchService` o similar) que llama a Gemini con **structured output** para parsear el texto a filtros (tipo de local, rango de precio, tags), y devuelve los merchants que matchean. Cada búsqueda queda registrada en `search_history` (`query_text` + `structured_output` tal cual lo devolvió Gemini).
  - **Consumers:** `GET /api/v1/me`, `PATCH /api/v1/me` — perfil propio.
  - **Visit summaries / Visits:** `GET /api/v1/me/visit_summaries` (fidelización por merchant), endpoint para simular el reconocimiento por DNI en el cierre de cuenta (crea un `Visit`, actualiza el `VisitSummary` correspondiente, aplica `loyalty_rules` si corresponde).
  - **Gifts:** `POST /api/v1/gifts`, `GET /api/v1/me/gifts`.
  - **Favorites:** `POST/DELETE /api/v1/favorites`, `GET /api/v1/me/favorites`.
  - **Search history:** `GET /api/v1/me/search_history`.
- **Archivos clave:** `app/controllers/api/v1/*`, `app/services/search/*`, `app/models/*`, `spec/requests/api/v1/*_spec.rb`, `spec/models/*_spec.rb`, `spec/swagger_helper.rb` + `swagger/v1/swagger.yaml` (generado por rswag).
- **Seguridad — DNI cifrado:** `dni_encrypted` (texto cifrado) + `dni_bidx` (blind index para poder buscar por igualdad sin desencriptar), tal como está en `backend/db/structure.sql`, implementado con las gemas `lockbox` + `blind_index`. Alternativa nativa considerada: `ActiveRecord::Encryption` de Rails 7+ con cifrado determinístico — se descarta como default porque el schema ya está dibujado con dos columnas separadas (`_encrypted` / `_bidx`), que es exactamente el patrón de Lockbox, no el de `ActiveRecord::Encryption` (que no necesita una columna de índice aparte).
- **Testing:**
  - RSpec unitario de modelos, con foco en la lógica de `loyalty_rules` (cálculo de tier según `visits_required`, distinción entre premio de una vez vs. `is_permanent`).
  - RSpec de integración (request specs) por endpoint, cubriendo casos felices y de error (401 sin token, 404, validaciones).
- **CI:** GitHub Actions (`.github/workflows/ci.yml`) corriendo `bundle exec rspec` en cada push, con un servicio Postgres en el job.
- **Qué no se hace:** delivery propio, reservas, ocupación en vivo, crédito compartido entre restaurantes, tocar el QR de pago/pedidos existente de Fudo, KYC real contra RENAPER, saldo parcial en gifts (todo o nada), ninguna columna/lógica de timezone.

---

## Fase 4 — Conectar ambos frontends al backend real

**Worktrees:** `fudo-mobile` y `fudo-web`, en paralelo entre sí. Depende de que Fase 2 **y** Fase 3 estén listas — es el punto de sincronización real del proyecto.

- **Entrega:** se reemplaza la capa local de fixtures (Fase 2) por la implementación real contra `/api/v1/`, sin tocar la interfaz que ya consumen las pantallas.
- **Archivos clave (mobile):** `lib/data/remote/remote_data_source.dart` (implementa la misma interfaz abstracta de Fase 2, usando `dio` o `http`), manejo de token con `flutter_secure_storage`, `test/widget/*_test.dart`.
- **Archivos clave (web):** reemplazo de los mocks en `lib/data/merchants.ts` por `fetch` real (server components donde aplique para SSR), manejo de sesión (cookie httpOnly), `__tests__/*.test.tsx` con Jest/Testing Library (o Vitest, según lo que haya quedado configurado en Fase 0 web).
- **Cómo se prueba:**
  - Flutter: widget tests con el cliente HTTP mockeado (`mockito`/`http_mock_adapter`), corriendo contra las respuestas reales documentadas en el OpenAPI de Fase 3.
  - Next.js: tests de componentes para el flujo de búsqueda y el flujo de regalo, mockeando `fetch`.
  - Manual: ambas apps corriendo contra el backend real levantado localmente (`docker compose up` en `fudo-backend`), verificar que los 30 merchants sembrados aparecen igual que en Fase 2.
- **Qué no se hace:** ninguna feature nueva — esta fase es integración pura, no cambia comportamiento.

---

## Fase 5 — Prueba end-to-end completa

**Worktree:** cualquiera con las 3 apps corriendo contra el mismo backend (o el checkout integrado en `main` después de mergear las fases anteriores). Depende de que Fase 4 esté terminada en mobile (web si el tiempo alcanzó). Es secuencial, un solo track.

- **Entrega:** el flujo completo de la demo verificado de punta a punta, con las 3 apps + backend corriendo a la vez:
  1. Buscar en lenguaje natural (ej. "algo picante y barato en Palermo").
  2. Ver el resultado (lista + mapa, detalle de un merchant con su menú).
  3. Simular el reconocimiento por DNI al cierre de cuenta (dispara la creación de un `Visit`).
  4. Ver la fidelización actualizada (el `VisitSummary` del merchant sube, y si corresponde se aplica una `loyalty_rule`).
  5. Regalar (crear un `Gift` y enviarlo).
  6. Ver el historial actualizado en "Mis Lugares" (visitas + regalos).
- **Cómo se prueba:** guion de demo manual paso a paso sobre el simulador/dispositivo real, más (si el tiempo alcanza) un test E2E automatizado con Playwright sobre la web o `integration_test` de Flutter cubriendo el mismo flujo.
- **Qué no se hace:** pruebas de carga, despliegue a producción, nada fuera del guion de la demo.

---

## Fuera de alcance en todo el proyecto (ver `PRD.md`)

Delivery propio · reservas de mesa · ocupación de mesas en vivo/predictiva · crédito de fidelización compartido entre restaurantes · tocar el QR de pedidos/pago existente de Fudo Comensal/Fudo Pay · login con Google (solo email + contraseña en el MVP) · KYC real sobre el DNI · saldo parcial en tarjetas de regalo (todo o nada) · `merchants.timezone` (toda la demo vive en una sola zona horaria, Buenos Aires).
