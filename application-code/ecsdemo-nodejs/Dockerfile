FROM public.ecr.aws/docker/library/node:22-bookworm-slim

# set the default NODE_ENV to production
# for dev/test build with: docker build --build-arg NODE=development .
# and the testing npms will be included
ARG NODE=production
ENV NODE_ENV=${NODE}

# copy package info early to install npms and delete npm command
WORKDIR /usr/src/app
COPY package*.json ./
RUN apt-get update && \
    apt-get install --yes --no-install-recommends bash curl iproute2 jq && \
    npm ci --omit=dev && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# copy the code
COPY --chown=node:node . .
USER node
HEALTHCHECK --interval=10s --timeout=3s \
  CMD curl -f -s http://localhost:3000/health/ || exit 1
EXPOSE 3000
ENTRYPOINT ["bash", "/usr/src/app/startup.sh"]
