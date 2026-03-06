# Build stage
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* pnpm-lock.yaml* bun.lockb* ./
{%- if cookiecutter.node_package_manager == "bun" %}
RUN npm install -g bun && bun install --frozen-lockfile
{%- elif cookiecutter.node_package_manager == "pnpm" %}
RUN npm install -g pnpm && pnpm install --frozen-lockfile
{%- else %}
RUN npm ci
{%- endif %}
COPY . .
RUN npm run build

# Production stage
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
