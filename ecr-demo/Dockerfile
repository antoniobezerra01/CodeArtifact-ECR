FROM node:20-bookworm-slim AS build

WORKDIR /workspace/app
COPY ecr-demo/app/package*.json ./
RUN npm ci
COPY ecr-demo/app/ ./
RUN npm run build

FROM nginx:1.27-alpine
COPY ecr-demo/nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /workspace/app/dist /usr/share/nginx/html
EXPOSE 80
