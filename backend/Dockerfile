# Development Dockerfile for the Fudo Consumers API.
# Not intended for production use — see the Rails guides for a multi-stage
# production build when that becomes necessary.

ARG RUBY_VERSION=3.4.10
FROM ruby:${RUBY_VERSION}-slim

# System dependencies:
# - build-essential, libffi-dev, pkg-config: compile native gem extensions (pg, argon2-kdf, etc.)
# - libpq-dev, postgresql-client: pg gem + psql client for connecting to Postgres
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
      build-essential \
      libpq-dev \
      libffi-dev \
      pkg-config \
      postgresql-client \
      git \
      curl && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /rails

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

RUN chmod +x bin/docker-entrypoint

EXPOSE 3000

ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["bin/rails", "server", "-b", "0.0.0.0", "-p", "3000"]
