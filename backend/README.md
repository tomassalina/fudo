# Fudo Consumers API

Rails API-only backend for **Fudo Consumers**, a restaurant loyalty app. See
the root [`README.md`](../README.md) for the full project pitch and the
[`AGENTS.md`](../AGENTS.md) stack table for canonical versions.

## Stack

- Ruby 3.4.10 / Rails 8.1.3.1 (API-only mode)
- PostgreSQL 18
- RSpec for testing (`spec/`, including `spec/integration/` request specs)
- Docker + docker-compose for local development
- `rack-cors` for cross-origin requests (Flutter / Next.js dev frontends)
- `bcrypt` for `has_secure_password`
- `lockbox` + `blind_index` for encrypting/searching sensitive attributes
  (e.g. national ID fields)
- `rswag-api` / `rswag-ui` / `rswag-specs` — OpenAPI docs generated from
  `spec/integration/`, served at `/api-docs`

## Requirements

- Docker and Docker Compose

## Running the app

```sh
cd backend
docker-compose up --build
```

This builds the `web` image, starts a `db` (Postgres) container, waits for
Postgres to be healthy, and boots the Rails server on
`http://localhost:3000`. On boot, `bin/docker-entrypoint` runs
`rails db:prepare`, which creates and migrates the database automatically.

Health check:

```sh
curl -i http://localhost:3000/up
```

should return `200 OK` (Rails' built-in health check route).

To stop and remove the containers (and the Postgres data volume):

```sh
docker-compose down -v
```

## Environment variables

Credentials are supplied as environment variables — nothing is hardcoded in
`config/database.yml`. By default they're set directly in
`docker-compose.yml`'s `environment:` blocks with sane local-dev defaults
(`POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `DB_HOST`, `DB_PORT`).
If you prefer a `.env` file instead, create one at `backend/.env` (already
git-ignored) with the same variable names — `dotenv-rails` and
docker-compose will both pick it up.

## Running tests

```sh
docker-compose run --rm web bundle exec rspec
```

## Project layout notes

- `config/initializers/cors.rb` allows any `localhost` origin (any port),
  over http or https, for all resources/methods — meant for local frontend
  development only.
- `spec/integration/api/v1/` holds the rswag request specs that double as
  the source for the OpenAPI doc served at `/api-docs` — see the root
  [`README.md`](../README.md#documentación-de-la-api).
