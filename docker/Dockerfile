FROM alpine:edge
RUN apk add --no-cache crystal shards libc-dev \
    yaml-dev libxml2-dev sqlite-dev zlib-dev curl && \
    curl -Lo /etc/apk/keys/omarroth.rsa.pub https://github.com/omarroth/boringssl-alpine/releases/download/1.1.0-r0/omarroth.rsa.pub && \
    curl -Lo boringssl-dev.apk https://github.com/omarroth/boringssl-alpine/releases/download/1.1.0-r0/boringssl-dev-1.1.0-r0.apk && \
    curl -Lo lsquic.apk https://github.com/omarroth/lsquic-alpine/releases/download/2.6.3-r0/lsquic-2.6.3-r0.apk && \
    apk update && \
    apk add boringssl-dev.apk lsquic.apk && \
    rm -rf /var/cache/apk/* boringssl-dev.apk lsquic.apk
WORKDIR /invidious
COPY ./shard.yml ./shard.yml
RUN shards update && shards install
RUN cp /usr/lib/libcrypto.a ./lib/lsquic/src/lsquic/ext/libcrypto.a && \
    cp /usr/lib/libssl.a ./lib/lsquic/src/lsquic/ext/libssl.a && \
    cp /usr/lib/liblsquic.a ./lib/lsquic/src/lsquic/ext/liblsquic.a
COPY ./src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./.git/ ./.git/
RUN crystal build --release --warnings all --error-on-warnings \
    # TODO: Remove next line, see https://github.com/crystal-lang/crystal/issues/7946
    -Dmusl \
    ./src/invidious.cr

RUN apk add --no-cache librsvg ttf-opensans
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious
COPY ./assets/ ./assets/
COPY ./config/config.yml ./config/config.yml
COPY ./config/sql/ ./config/sql/
COPY ./locales/ ./locales/
RUN sed -i 's/host: \(127.0.0.1\|localhost\)/host: postgres/' config/config.yml
USER invidious
CMD [ "/invidious/invidious" ]
