# Development Dockerfile for the Fudo Consumers API.
# Not intended for production use — see the Rails guides for a multi-stage
# production build when that becomes necessary.

ARG RUBY_VERSION=3.4.10
FROM ruby:${RUBY_VERSION}-slim

# System dependencies:
# - build-essential, libffi-dev, pkg-config: compile native gem extensions (pg, argon2-kdf, etc.)
# - libpq-dev, postgresql-client-18: pg gem + psql/pg_dump client for connecting to Postgres.
#   Pinned to major version 18 via the PGDG apt repo because Debian trixie's
#   default `postgresql-client` package ships v17, which cannot pg_dump
#   against the postgres:18 server used in docker-compose.yml (schema_format
#   :sql runs pg_dump on every db:migrate, and pg_dump refuses to talk to a
#   newer server).
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libffi-dev \
      pkg-config \
      git \
      curl \
      ca-certificates \
      lsb-release && \
    install -d /usr/share/postgresql-common/pgdg && \
    curl -sSf -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc https://www.postgresql.org/media/keys/ACCC4CF8.asc && \
    echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y libpq-dev postgresql-client-18 && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /rails

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN chmod +x bin/docker-entrypoint

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
