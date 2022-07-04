FROM elixir:1.13.4-alpine AS build

# install build dependencies
RUN \
    apk add --no-cache \
    build-base \
    npm \
    git \
    python3 \
    make \
    cmake \
    openssl-dev \ 
    libsrtp-dev \
    libnice-dev \
    ffmpeg-dev \
    clang-dev

# Create build workdir
WORKDIR /app

# install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# set build ENV
ENV MIX_ENV=prod

# install mix dependencies
COPY mix.exs mix.lock ./
COPY config config
RUN mix do deps.get, deps.compile

# compile and build release
COPY lib lib

RUN mix do compile, release

# prepare release image
FROM alpine:3.16 AS app

# install runtime dependencies
RUN \
    apk add --no-cache \
    openssl \
    ncurses-libs \
    libsrtp \
    libnice \
    ffmpeg \
    clang \ 
    curl

WORKDIR /app

COPY docker-entrypoint.sh ./docker-entrypoint.sh

RUN chmod +x docker-entrypoint.sh

ENTRYPOINT [ "./docker-entrypoint.sh" ]

COPY --from=build /app/_build/prod/rel/hls_proxy_api ./

# ENV HOME=/app

CMD ["bin/hls_proxy_api", "start"]
