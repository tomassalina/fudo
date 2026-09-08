# Fudo Consumers API

Rails API-only backend scaffold for **Fudo Consumers**, a restaurant loyalty
app prototype. This is a scaffolding step only: no business models, real
endpoints, or hand-written migrations exist yet — that comes in a later
phase. What's here is the boot-ready application shell (Rails 7.2, Ruby 3.3,
PostgreSQL, Docker, RSpec, CORS).

## Stack

- Ruby 3.3.12 / Rails 7.2 (API-only mode)
- PostgreSQL 16
- RSpec (instead of Minitest) for testing
- Docker + docker-compose for local development
- `rack-cors` for cross-origin requests (Flutter / Next.js dev frontends)
- `bcrypt` for `has_secure_password`
- `lockbox` + `blind_index` for encrypting/searching sensitive attributes
  (e.g. national ID fields) in a later phase

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

There are no example specs yet (RSpec is installed and configured via
`rails generate rspec:install`).

## Project layout notes

- `app/services/` and `app/serializers/` exist as empty scaffolding
  (`.keep` files only) — service objects and serialization logic land in
  the next phase.
- `config/initializers/cors.rb` allows any `localhost` origin (any port),
  over http or https, for all resources/methods — meant for local frontend
  development only.

## Verification status

Docker build and boot were verified on this machine: `docker-compose up
--build` was run, `GET /up` returned `200 OK`, `bundle exec rspec` ran
successfully (0 examples, 0 failures), and the containers/volumes were torn
down (`docker-compose down -v`) afterwards, so no local state is left behind
by this scaffold.
