# Fudo Consumers

App mobile de fidelización, descubrimiento con IA y regalos para el ecosistema de restaurantes de [Fudo](https://fudo.com). Fudo es el único actor presente en cada venta de un restaurante, sin importar el método de pago — esa presencia transversal es la ventaja injusta del producto: no es que Fudo ya conozca al comensal, es que es el único que puede llegar a conocerlo.

El producto tiene tres pestañas (mobile, prioridad principal):

- **Buscar** — buscador en lenguaje natural sobre el menú y precio real de cada local, resultados en lista y en mapa.
- **Mis Lugares** — perfil gastronómico armado con IA, fidelización por restaurante visitado.
- **Regalar** — compra y envío de tarjetas de regalo por niveles (classic/gold/black/platinum).

Se acompaña de una web en Next.js (SSR), de menor prioridad, pensada a futuro para SEO. Ver el detalle completo del problema, la ventaja injusta y las decisiones de producto en [`PRD.md`](./PRD.md).

> Estado: MVP / demo en desarrollo. Datos 100% ficticios (30 merchants en Palermo, CABA).

## Stack

| Plataforma | Tecnologías | Versión |
|---|---|---|
| **Backend** | Ruby on Rails (API-only), PostgreSQL, Docker | Ruby 3.4.10 · Rails 8.1.3.1 · pg ~> 1.6 · Puma ~> 8.0 · Postgres 18 |
| **Mobile** | Flutter, Dart, Riverpod, go_router | Flutter 3.47.2 · Dart 3.13.2 · flutter_riverpod ^3.4.3 · go_router ^18.0.1 |
| **Web** | Next.js (App Router, SSR), TypeScript, Tailwind | Node 24 LTS · Next.js 16.3.4 · React 19.2.8 · TypeScript 6.0.3 · pnpm 10.21.0 |
| **IA** | Gemini API (parser de búsqueda en lenguaje natural, structured output) | Llamado siempre desde el backend, nunca desde los clientes |
| **Analytics / feature flags** | PostHog Cloud | Nunca self-hosteado |

Las versiones de arriba son las que efectivamente quedaron instaladas y **verificadas de punta a punta**: `docker compose build && up` + `curl localhost:3000/up` (200 OK) para el backend, `flutter analyze` limpio para mobile, `pnpm run build && pnpm run lint` limpios para web. TypeScript se mantiene en 6.0.3 (no 7.x) y ESLint en 9.39.5 (no 10.x) porque `eslint-config-next` todavía no soporta esas majors — no es una versión vieja por descuido, es la más nueva que compila de verdad hoy.

## Estructura del repo

```
fudo/
├── backend/    # API Rails (modo API-only), Docker Compose, PostgreSQL
├── mobile/     # App Flutter — lib/{core,features,shared}, 3 tabs
├── web/        # Web Next.js — App Router, SSR
├── docs/
│   ├── database-schema.drawio  # diseño de referencia hecho a mano (14 tablas + 7 enums)
│   └── database-schema.png
├── openspec/
│   └── changes/fudo-consumers-mvp/
│       ├── proposal.md
│       └── design.md       # decision log del proyecto (13 decisiones)
├── PRD.md      # documento de producto
├── PLAN.md     # plan técnico de construcción, 6 fases
└── AGENTS.md   # contexto canónico para agentes/contribuidores (CLAUDE.md apunta acá)
```

## Quickstart

### Backend

```bash
cd backend
docker compose up
# healthcheck: curl -i http://localhost:3000/up  ->  200 OK
```

`docker compose up` levanta Postgres 18 (servicio `db`) y la API Rails (servicio `web`, puerto 3000). No requiere `config/master.key` para arrancar en desarrollo (solo hace falta si se accede a credenciales cifradas). Alternativa sin Docker:

```bash
cd backend && bundle install && rails db:setup && rails server
```

### Mobile

```bash
cd mobile
flutter pub get
flutter run
```

Requiere Flutter 3.47.2 / Dart 3.13.2 o superior (ver `environment.sdk` en `mobile/pubspec.yaml`).

### Web

```bash
cd web
pnpm install
pnpm dev
```

El proyecto usa **pnpm** (ver `packageManager` en `web/package.json`), no npm ni yarn. Requiere Node 24 LTS o superior (`engines.node` en `web/package.json`).

## Documentación

1. [`PRD.md`](./PRD.md) — problema, ventaja injusta, alcance y fuera de alcance del producto.
2. [`PLAN.md`](./PLAN.md) — plan técnico en 6 fases, cómo se trabajó en paralelo (worktrees de git).
3. [`backend/db/structure.sql`](./backend/db/structure.sql) — fuente de verdad ejecutable del esquema de base de datos, generada por Rails.
4. [`docs/database-schema.drawio`](./docs/database-schema.drawio) — diagrama visual del esquema, hecho a mano.
5. [`openspec/changes/fudo-consumers-mvp/design.md`](./openspec/changes/fudo-consumers-mvp/design.md) — decision log técnico (13 decisiones, con su "por qué").
6. [`AGENTS.md`](./AGENTS.md) — contexto canónico para cualquier persona o agente que trabaje en el repo (`CLAUDE.md` es un alias que apunta acá).

## Convenciones

- **Commits**: [conventional commits](https://www.conventionalcommits.org/) con scope de carpeta/área entre paréntesis, por ejemplo `feat(/mobile): add gifting screen`, `fix(/backend): correct visit_summary tier calculation`, `docs(/openspec): add decision log`.
- **Testing**: RSpec para el backend (`backend/spec/`).
- **Fuera de alcance** (decidido explícitamente, no es un olvido — detalle completo en `PRD.md`): delivery propio, reservas de mesa, ocupación de mesas en vivo, crédito de fidelización compartido entre restaurantes, login con Google, KYC real sobre el DNI, saldo parcial en tarjetas de regalo. Tampoco se toca el QR de pedidos/pago existente de Fudo Comensal — es producto de otro equipo, límite de alcance explícito (ver `design.md`, Decisión 1).
- **PostHog**: nunca self-hosteado, siempre Cloud.
