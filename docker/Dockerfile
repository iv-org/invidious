FROM crystallang/crystal:0.36.1-alpine AS builder
RUN apk add --no-cache curl sqlite-static yaml-static
WORKDIR /invidious
COPY ./shard.yml ./shard.yml
COPY ./shard.lock ./shard.lock
RUN shards install && \
    curl -Lo ./lib/lsquic/src/lsquic/ext/liblsquic.a https://github.com/iv-org/lsquic-static-alpine/releases/download/v2.18.1/liblsquic.a
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
COPY --chown=invidious ./config/config.* ./config/
RUN mv -n config/config.example.yml config/config.yml
RUN sed -i 's/host: \(127.0.0.1\|localhost\)/host: postgres/' config/config.yml
COPY ./config/sql/ ./config/sql/
COPY ./locales/ ./locales/
COPY --from=builder /invidious/invidious .
RUN chmod o+rX -R ./assets ./config ./locales

EXPOSE 3000
USER invidious
CMD [ "/invidious/invidious" ]
