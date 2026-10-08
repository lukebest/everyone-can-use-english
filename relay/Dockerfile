FROM node:22-bookworm-slim

RUN apt-get update \
  && apt-get install -y --no-install-recommends ffmpeg ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src ./src
RUN npm run build && npm prune --omit=dev

ENV PORT=8787 \
    DATA_DIR=/app/data \
    REQUEST_TIMEOUT_MS=60000 \
    MAX_CONCURRENCY=2 \
    NODE_OPTIONS=--experimental-sqlite
EXPOSE 8787
VOLUME ["/app/data"]
CMD ["node", "dist/index.js"]
