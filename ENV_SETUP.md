# ENV_SETUP.md — Configuración de variables de entorno

Checklist paso a paso para que cualquiera pueda levantar las 3 apps de Fudo Consumers (backend, mobile, web) con todas las variables de entorno que hacen falta. Seguilo en orden — está pensado para no tener que volver a preguntar nada.

Contexto técnico completo de cada variable: ver los comentarios dentro de `backend/.env.example`, `mobile/.env.example` y `web/.env.example`. Este documento es la guía de "qué hacer con la mano", esos archivos son la referencia de "qué es cada variable".

## 0. Antes de arrancar

- [ ] Copiá cada `.env.example` a su versión real, **sin borrar los comentarios** (te sirven de referencia después):
  ```bash
  cp backend/.env.example backend/.env
  cp mobile/.env.example mobile/.env
  cp web/.env.example web/.env.local
  ```
  (Web usa `.env.local` por convención de Next.js — ya está en el `.gitignore` de `web/` igual que `.env`.)

## 1. Backend — Postgres

- [ ] No hace falta hacer nada: `backend/.env` ya tiene los mismos valores por default que `backend/docker-compose.yml` (`POSTGRES_USER=fudo`, `POSTGRES_PASSWORD=fudo_password`, `POSTGRES_DB=fudo_consumers_development`). Sirven tal cual para desarrollo local.
- [ ] Si vas a correr `rails server` **fuera** de Docker (no vía `docker compose up`), dejá `DB_HOST=localhost`. Si Rails corre **dentro** del contenedor `web` del compose, no toques nada — el propio `docker-compose.yml` ya fuerza `DB_HOST=db` en ese contexto.

## 2. Backend — cifrado del DNI (Lockbox + blind_index)

- [ ] **Antes de generar nada**: preguntá si el worktree `db-phase1` (Fase 1, migraciones + seeders) ya generó una `LOCKBOX_MASTER_KEY` para poder correr los seeders. Si existe, usá esa misma clave en tu `backend/.env` — no generes una segunda que quede sin usar. (Al momento de esta auditoría no había ninguna generada todavía.)
- [ ] Si no existe ninguna, generá la clave de Lockbox corriendo esto en una terminal:
  ```bash
  ruby -rsecurerandom -e "puts SecureRandom.hex(32)"
  ```
  (alternativa si no tenés Ruby a mano: `openssl rand -hex 32`). Copiá el resultado tal cual en `LOCKBOX_MASTER_KEY=` dentro de `backend/.env`.
- [ ] Generá una segunda clave, distinta, para `BLIND_INDEX_MASTER_KEY=` corriendo el mismo comando de nuevo:
  ```bash
  ruby -rsecurerandom -e "puts SecureRandom.hex(32)"
  ```

## 3. Backend — Gemini API (búsqueda en lenguaje natural)

- [ ] Entrá a **https://aistudio.google.com/apikey** (Google AI Studio) con tu cuenta de Google.
- [ ] Creá una API key nueva (es gratis para uso de desarrollo).
- [ ] Pegala tal cual te la da Google en `GEMINI_API_KEY=` dentro de `backend/.env` — no le cambies el formato ni le agregues comillas.

## 4. PostHog (mobile + web)

- [ ] Creá una cuenta / proyecto en **https://posthog.com** (PostHog Cloud — nunca self-hosteado en este proyecto).
- [ ] Dentro del proyecto, andá a **Project Settings** y copiá el **Project API Key**.
- [ ] Fijate en esa misma pantalla la región de tu proyecto (US o EU) para saber qué host usar.
- [ ] Pegá la key y el host en `mobile/.env`:
  ```
  POSTHOG_API_KEY=<tu key>
  POSTHOG_HOST=https://us.i.posthog.com   # o https://eu.i.posthog.com si tu proyecto es EU
  ```
- [ ] Repetí lo mismo en `web/.env.local`:
  ```
  NEXT_PUBLIC_POSTHOG_KEY=<tu key>
  NEXT_PUBLIC_POSTHOG_HOST=https://us.i.posthog.com   # o https://eu.i.posthog.com
  ```
  Esta key **no se puede generar localmente** — sale de tu cuenta de PostHog Cloud sí o sí.

## 5. Mobile — cómo correr la app con estas variables

- [ ] Flutter lee `mobile/.env` de forma nativa con:
  ```bash
  flutter run --dart-define-from-file=.env
  ```
- [ ] `mobile/lib/core/analytics/analytics_service.dart` ya lee `POSTHOG_API_KEY`/`POSTHOG_HOST` vía `String.fromEnvironment` — sin `--dart-define-from-file=.env` (o sin llenar esas variables), la app arranca igual con analytics deshabilitado (no hace ninguna llamada de red a PostHog).
- [ ] Fase 4 (`PLAN.md`) ya está implementada y probada contra el backend real: `mobile/lib/data/connection_mode.dart` lee `CONNECTION_MODE` (`local`, default, sin backend — o `remote`, pega de verdad a `/api/v1`) y `mobile/lib/core/config/dio_client.dart` lee `API_BASE_URL` (default `http://localhost:3000/api/v1`), ambas también vía `String.fromEnvironment`. No hace falta agregarlas a `mobile/.env` para el flujo normal — se pasan como `--dart-define` sueltos en el comando de `flutter run` (ver el README raíz, sección "Mobile"), ya que cambian según cómo estés corriendo la app (local vs. contra el backend, emulador Android vs. simulador iOS) más que ser un secreto fijo por desarrollador. `GEMINI_API_KEY` y el resto de las variables de backend siguen sin leerse desde `mobile/lib/` — esas viven del lado del backend, mobile nunca las necesita directamente.

## 6. Web — cómo correr la app con estas variables

- [ ] Next.js lee automáticamente `web/.env.local` al correr `pnpm dev` — no hace falta ningún flag adicional.
- [ ] `NEXT_PUBLIC_API_BASE_URL` ya está siendo usada por `web/lib/api/client.ts` — con dejar el default (`http://localhost:3000/api/v1`) alcanza si el backend corre local en el puerto 3000.

## 7. Rails master key — nota, no bloqueante

- [ ] No hace falta hacer nada por ahora. `backend/config/credentials.yml.enc` ya existe en el repo (viene del scaffold inicial de `rails new`), pero ningún código del proyecto lee `Rails.application.credentials` todavía, así que la ausencia de `config/master.key` no rompe nada hoy.
- [ ] Si en el futuro algo empieza a pedirlo (error tipo `ActiveSupport::MessageEncryptor::InvalidMessage` o "Missing master key"), **no corras `rails credentials:edit` para generar una clave nueva** — eso re-encripta el archivo ya commiteado con una clave distinta a la que tiene el resto del equipo. Pedile el `config/master.key` real a quien corrió `rails new` originalmente (o coordinen para regenerar credenciales entre todos si se perdió).

## 8. Verificación final

- [ ] Backend: `cd backend && docker compose up` y confirmá que `curl localhost:3000/up` responde `200`.
- [ ] Backend (una vez que Fase 1 tenga migraciones + seeders): `rails db:setup` corre sin errores y `Consumer.first.dni_bidx` es buscable.
- [ ] Mobile: `cd mobile && flutter pub get && flutter run --dart-define-from-file=.env`.
- [ ] Web: `cd web && pnpm install && pnpm dev`, la página carga en `localhost:3000`.

## 9. Nunca comitear

Los tres `.gitignore` (`backend/`, `mobile/`, `web/`) ya están configurados para ignorar `.env`, `.env.local` y variantes, pero **sí** dejan pasar los `.env.example` (son plantillas sin secretos reales). Antes de cualquier commit, revisá con `git status` que ningún archivo con valores reales quede staged.
