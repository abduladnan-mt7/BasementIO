# BasementIO template: Node backend (Express, NestJS, Hono, Fastify, workers)
# Works with npm, pnpm or yarn. Runs the "build" script if there is one.
# Set CMD to your entry file at the bottom.

FROM node:24-alpine AS base
WORKDIR /app

# All dependencies, for building
FROM base AS deps
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
RUN if [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install --frozen-lockfile; \
    elif [ -f yarn.lock ]; then corepack enable yarn && yarn install --frozen-lockfile; \
    elif [ -f package-lock.json ]; then npm ci; \
    else echo "No lockfile found; commit one." && exit 1; fi

# Production dependencies only, for the final image
FROM base AS prod-deps
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
RUN if [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install --prod --frozen-lockfile; \
    elif [ -f yarn.lock ]; then corepack enable yarn && yarn install --production --frozen-lockfile; \
    else npm ci --omit=dev; fi

FROM deps AS build
COPY . .
RUN npm run build --if-present && rm -rf node_modules

FROM base AS run
# tini as PID 1 forwards SIGTERM so the app can shut down gracefully on redeploys
RUN apk add --no-cache tini
ENV NODE_ENV=production PORT=3000
COPY --from=build --chown=node:node /app ./
COPY --from=prod-deps --chown=node:node /app/node_modules ./node_modules
USER node
EXPOSE 3000
ENTRYPOINT ["/sbin/tini", "--"]
# Change to your entry file (e.g. src/server.js). Keep comments on their own line:
# text after the closing ] breaks the JSON and Docker silently switches to shell form.
CMD ["node", "dist/index.js"]
