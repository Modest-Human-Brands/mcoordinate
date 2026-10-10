FROM oven/bun:1-alpine AS builder

WORKDIR /app

COPY package.json bun.lock ./

RUN bun install --frozen-lockfile

COPY . .

RUN bunx motia build

FROM debian:bookworm-slim@sha256:7c7b2c966bc9ee8cedfeef67e0e279108992c77681fa595db4a9d65c06ccc587 AS iii-installer

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://install.iii.dev/iii/main/install.sh | bash

FROM oven/bun:1-alpine AS runner

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