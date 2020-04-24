FROM alpine:edge AS builder
RUN apk add --no-cache curl crystal shards libc-dev \
    yaml-dev libxml2-dev sqlite-dev zlib-dev openssl-dev \
    yaml-static sqlite-static zlib-static openssl-libs-static
WORKDIR /invidious
COPY ./shard.yml ./shard.yml
RUN shards update && shards install && \
    curl -Lo /etc/apk/keys/omarroth.rsa.pub https://github.com/omarroth/boringssl-alpine/releases/download/1.1.0-r0/omarroth.rsa.pub && \
    curl -Lo boringssl-dev.apk https://github.com/omarroth/boringssl-alpine/releases/download/1.1.0-r0/boringssl-dev-1.1.0-r0.apk && \
    curl -Lo lsquic.apk https://github.com/omarroth/lsquic-alpine/releases/download/2.6.3-r0/lsquic-2.6.3-r0.apk && \
    apk verify --no-cache boringssl-dev.apk lsquic.apk && \
    tar -xf boringssl-dev.apk usr/lib/libcrypto.a usr/lib/libssl.a && \
    tar -xf lsquic.apk usr/lib/liblsquic.a && \
    mv usr/lib/* lib/lsquic/src/lsquic/ext && \
    rm -r usr boringssl-dev.apk lsquic.apk /root/.cache
COPY ./src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./.git/ ./.git/
RUN crystal build ./src/invidious.cr \
    --static --warnings all --error-on-warnings \
    --link-flags "-lxml2 -llzma"

FROM alpine:latest
RUN apk add --no-cache librsvg ttf-opensans
WORKDIR /invidious
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious
COPY ./assets/ ./assets/
COPY --chown=invidious ./config/config.yml ./config/config.yml
RUN sed -i 's/host: \(127.0.0.1\|localhost\)/host: postgres/' config/config.yml
COPY ./config/sql/ ./config/sql/
COPY ./locales/ ./locales/
COPY --from=builder /invidious/invidious .

USER invidious
CMD [ "/invidious/invidious" ]
