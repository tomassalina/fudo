# AGENTS.md — Fudo Consumers

Contexto canónico del proyecto para cualquier persona o agente que trabaje en este repo, incluyendo worktrees paralelos. Leelo antes de preguntar algo que ya está documentado acá.

## Qué es el proyecto

Fudo Consumers es una app mobile de fidelización, descubrimiento con IA y regalos para el ecosistema de restaurantes de Fudo. La ventaja competitiva del proyecto es que Fudo es el único actor presente en cada venta de un restaurante, sin importar el método de pago. Se acompaña de una web secundaria (menor prioridad) pensada a futuro para SEO.

## Stack por plataforma

| Plataforma | Tecnologías |
|---|---|
| Mobile | Flutter, Dart, Riverpod (state management), go_router (navegación) |
| Backend | Ruby on Rails (modo API), PostgreSQL, Docker |
| Web | Next.js (SSR) — menor prioridad, se construye al final si sobra tiempo |
| IA | Gemini API (parser de búsqueda en lenguaje natural, structured output, llamado siempre desde el backend) |
| Analytics / feature flags | PostHog Cloud (nunca self-hosteado) |

## Estructura del repo

| Path | Contenido |
|---|---|
| `backend/` | API Rails |
| `mobile/` | App Flutter |
| `web/` | Web Next.js |
| `db/schema.sql` | Fuente de verdad ejecutable del esquema de base de datos |
| `docs/` | Diagramas, incluyendo `database-schema.drawio` |
| `openspec/` | Registro de decisiones y propuestas (SDD) |
| `PRD.md` | Documento de producto |
| `PLAN.md` | Plan de fases del proyecto |

Nota: al momento de escribir este documento, `PLAN.md`, `db/schema.sql` y `docs/database-schema.drawio` todavía no existen en el repo — otro agente los está armando en paralelo en otro worktree. No asumas su contenido; leelos cuando existan.

## Documentos a leer primero, en este orden

1. `PRD.md`
2. `PLAN.md`
3. `db/schema.sql`
4. `docs/database-schema.drawio`
5. `openspec/changes/fudo-consumers-mvp/design.md`

## Convenciones

- Conventional commits.
- RSpec para tests de backend.
- No tocar el QR de pedidos/pago existente de Fudo Comensal — es producto de otro equipo, límite de alcance explícito (ver `openspec/changes/fudo-consumers-mvp/design.md`, Decisión 1).
- Nunca self-hostear PostHog.

## Cómo levantar cada app

Comandos aproximados — todavía pueden no estar 100% probados en este repo.

**Backend**
```bash
cd backend && bundle install && rails db:setup && rails server
# o vía Docker:
docker compose up
```

**Mobile**
```bash
cd mobile && flutter pub get && flutter run
```

**Web**
```bash
cd web && npm install && npm run dev
```
