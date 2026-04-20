FROM alpine:3.20 AS downloader

ARG STACK_VERSION
ARG ARTIFACT_DOWNLOADS_BASE_URL=https://artifacts.elastic.co/downloads

ENV DOWNLOAD_BASE_DIR=/opt/elastic-packages

RUN apk add --no-cache bash curl coreutils

COPY scripts/download-artifacts.sh /usr/local/bin/download-artifacts.sh

RUN chmod +x /usr/local/bin/download-artifacts.sh \
    && /usr/local/bin/download-artifacts.sh

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/nginx.conf
COPY --from=downloader /opt/elastic-packages /opt/elastic-packages

RUN mkdir -p /var/cache/nginx /var/log/nginx \
    && touch /tmp/nginx.pid \
    && chown -R nginx:nginx /var/cache/nginx /var/log/nginx /tmp/nginx.pid

USER nginx

EXPOSE 9080
