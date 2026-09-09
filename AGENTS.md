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
| `docs/` | Diagramas y diseño de referencia visual del esquema (`database-schema.drawio`, `database-schema.png`) |
| `openspec/` | Registro de decisiones y propuestas (SDD) |
| `PRD.md` | Documento de producto |
| `PLAN.md` | Plan de fases del proyecto |

> **Nota sobre el esquema de base de datos:** la fuente de verdad ejecutable real que usa Rails día a día es `backend/db/structure.sql` (migraciones + `schema_format = :sql`, necesario por los enums nativos de Postgres). El diagrama visual `docs/database-schema.drawio` es diseño de referencia hecho a mano y se mantiene junto a `backend/db/structure.sql`.

## Documentos a leer primero, en este orden

1. `PRD.md`
2. `PLAN.md`
3. `backend/db/structure.sql`
4. `docs/database-schema.drawio`
5. `openspec/changes/fudo-consumers-mvp/design.md`
6. `openspec/changes/fudo-consumers-mvp/learnings.md`

## Convenciones

- Conventional commits.
- RSpec para tests de backend.
- No tocar el QR de pedidos/pago existente de Fudo Comensal — es producto de otro equipo, límite de alcance explícito (ver `openspec/changes/fudo-consumers-mvp/design.md`, Decisión 1).
- Nunca self-hostear PostHog.

## Documentar decisiones antes de cerrar una tarea (obligatorio)

Cualquier persona o agente que trabaje en este repo y, durante su tarea, tome una **decisión de arquitectura o de producto no trivial** (una elección con alternativas descartadas, no un detalle de implementación mecánico) o aprenda **algo no obvio** (un gotcha, una limitación técnica real, una razón de negocio que no estaba escrita en ningún lado) **tiene que documentarlo en `openspec/`** — en `openspec/changes/fudo-consumers-mvp/learnings.md` (o el archivo de decisiones vigente del change activo) — **antes de dar la tarea por cerrada**. No es opcional ni queda a criterio de "si hay tiempo". Seguí el formato ya usado en `design.md`/`learnings.md`: qué se decidió, por qué, y qué alternativas se descartaron y por qué. No inventes decisiones que no pasaron de verdad — documentá solo lo que efectivamente se decidió o se aprendió en tu tarea.

## Cómo levantar cada app

**Backend**
```bash
cd backend && bundle install && rails db:setup && rails server
# o vía Docker (recomendado, ya verificado — curl localhost:3000/up responde 200):
cd backend && docker compose up
```

**Mobile**
```bash
cd mobile && flutter pub get && flutter run
```

**Web**
```bash
cd web && pnpm install && pnpm dev
```
Nota: el proyecto usa pnpm (ver `packageManager` en `web/package.json` y `web/pnpm-lock.yaml`), no npm.
