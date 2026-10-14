# BasementIO template: static sites and SPAs (Vite, React, Vue, Astro static, etc.)
# Builds with Node, serves with nginx. Single-page-app routing included.
# Plain HTML with no build step? Delete the build stage and COPY your files directly.

FROM node:24-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* pnpm-lock.yaml* yarn.lock* ./
RUN if [ -f pnpm-lock.yaml ]; then corepack enable pnpm && pnpm install --frozen-lockfile; \
    elif [ -f yarn.lock ]; then corepack enable yarn && yarn install --frozen-lockfile; \
    else npm ci; fi
COPY . .
# VITE_* (and similar) values are compiled in at build time. Declare each one and
# tick "Build Variable" for it in the dashboard:
# ARG VITE_API_URL
RUN npm run build

FROM nginx:stable-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
# Vite outputs dist/, Create React App outputs build/: adjust if needed
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
