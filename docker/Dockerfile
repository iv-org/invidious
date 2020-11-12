FROM crystallang/crystal:0.35.1-alpine AS builder
RUN apk add --no-cache curl sqlite-static
WORKDIR /invidious
COPY ./shard.yml ./shard.yml
RUN shards update && shards install && \
    # TODO: Document build instructions
    # See https://github.com/omarroth/boringssl-alpine/blob/master/APKBUILD,
    # https://github.com/omarroth/lsquic-alpine/blob/master/APKBUILD,
    # https://github.com/omarroth/lsquic.cr/issues/1#issuecomment-631610081
    # for details building static lib
    curl -Lo ./lib/lsquic/src/lsquic/ext/liblsquic.a https://omar.yt/lsquic/liblsquic-v2.18.1.a
COPY ./src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./.git/ ./.git/
RUN crystal build ./src/invidious.cr \
    --static --warnings all \
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
