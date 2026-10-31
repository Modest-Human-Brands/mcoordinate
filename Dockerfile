FROM oven/bun:1-alpine@sha256:4cf82f5686b196504fe119db3fcd9185b191f82ece82c40680e597228ec6070a AS builder

WORKDIR /app

COPY package.json bun.lock ./

RUN bun install --frozen-lockfile

COPY . .

RUN bunx motia build

FROM debian:bookworm-slim@sha256:99c0b25c46d0214d5a2091092e7908907dcaecd6a962cde0ac700acee222b6f3 AS iii-installer

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://install.iii.dev/iii/main/install.sh | bash

FROM oven/bun:1-alpine@sha256:4cf82f5686b196504fe119db3fcd9185b191f82ece82c40680e597228ec6070a AS runner

ARG VERSION
ARG BUILD_TIME

RUN apk add --no-cache \
	--repository=https://dl-cdn.alpinelinux.org/alpine/edge/main \
	--repository=https://dl-cdn.alpinelinux.org/alpine/edge/community \
	ffmpeg

RUN apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/testing steghide

WORKDIR /app

COPY --from=iii-installer /root/.local/bin/iii /usr/local/bin/iii

COPY --from=builder /app/package.json .
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY iii-config-production.yaml .

ENV NODE_ENV=production
ENV MOTIA_APP_VERSION=$VERSION
ENV MOTIA_APP_BUILD_TIME=$BUILD_TIME

EXPOSE 3111
EXPOSE 3112
EXPOSE 49134

CMD ["iii", "--config", "iii-config-production.yaml"]