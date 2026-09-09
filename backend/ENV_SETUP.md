# Environment setup

This backend is configured entirely through environment variables — nothing
sensitive is hardcoded in `config/`. Copy `.env.example` to `.env` and fill
in real values:

```sh
cd backend
cp .env.example .env
```

`.env` is already covered by `.gitignore`'s `/.env*` pattern (with
`.env.example` explicitly allowlisted so this template stays committed) —
never commit your real `.env`. `dotenv-rails` (see `Gemfile`) loads it
automatically in development and test; docker-compose picks it up too if
you run through `docker-compose up`.

## Variables

| Variable | Required | Purpose |
|---|---|---|
| `DB_HOST`, `DB_PORT`, `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | Yes | Postgres connection (`config/database.yml`). Defaults already match `docker-compose.yml`. |
| `POSTGRES_TEST_DB` | Test only | Database used by `bundle exec rspec`. |
| `RAILS_MAX_THREADS` | No | ActiveRecord pool size / Puma thread count. Defaults to 5. |
| `JWT_SECRET` | Production | Signs consumer auth tokens (`app/lib/json_web_token.rb`). App raises at boot in production if unset (`config/initializers/jwt_secret_check.rb`). Generate with `bin/rails secret`. Optional in dev/test (falls back to `secret_key_base`). |
| `LOCKBOX_MASTER_KEY`, `BLIND_INDEX_MASTER_KEY` | Yes (for any `Consumer#dni` code path, including `db/seeds.rb`) | Field-level encryption + blind index for `Consumer#dni` (`config/initializers/lockbox.rb`). Generate each with `bin/rails runner 'puts SecureRandom.hex(32)'` — use two **different** values. |
| `GEMINI_API_KEY` | Yes (for search) | Natural-language search parsing (`app/services/search_query_parser.rb`). Get a key from [Google AI Studio](https://aistudio.google.com/apikey). |
| `GEMINI_MODEL` | No | Defaults to `gemini-flash-latest`. |
| `CORS_ALLOWED_ORIGINS` | Production | Comma-separated allowed origins (`config/initializers/cors.rb`). Any `localhost` origin is already allowed in development regardless of this. |
| `PORT` | No | Puma port, defaults to 3000. |
| `PIDFILE` | No | Puma pidfile path, unset by default. |
| `RAILS_LOG_LEVEL` | No | Defaults to `info` in production. |

For production, `RAILS_MASTER_KEY` (or `config/master.key`) is also
required to decrypt Rails credentials — that's Rails' own credentials
mechanism, not an app-specific variable, so it isn't in `.env.example`.

## Local dev shortcut

`db/seeds.rb` generates throwaway `LOCKBOX_MASTER_KEY` /
`BLIND_INDEX_MASTER_KEY` values suitable for local demo data only — see the
comment at the top of that file. Replace them with real secrets management
(Rails credentials, Docker secrets, a vault, etc.) before relying on
anything beyond local dev/demo.
