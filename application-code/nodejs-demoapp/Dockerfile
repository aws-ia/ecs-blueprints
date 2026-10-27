ARG IMAGE_BASE=22-alpine3.24

FROM node:$IMAGE_BASE
LABEL Name="Node.js Demo App" Version=4.8.6
LABEL org.opencontainers.image.source="https://github.com/benc-uk/nodejs-demoapp"
ENV NODE_ENV=production
WORKDIR /app

# For running tests
RUN apk add --no-cache make

# For Docker layer caching do this BEFORE copying in rest of app
COPY src/package*.json ./
RUN npm ci --omit=dev --silent

# NPM is done, now copy in the rest of the project to the workdir
COPY --chown=node:node src/. .

# Run as the unprivileged built-in node user; the app listens on
# non-privileged port 3000 (PORT env default), so root is not needed
USER node

# Port 3000 for our Express server
EXPOSE 3000

# Health check against the home page (also the ALB health check path used by
# the blueprints); busybox wget ships with the alpine base image
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -q --spider http://localhost:3000/ || exit 1

ENTRYPOINT ["npm", "start"]
