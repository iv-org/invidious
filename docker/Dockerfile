FROM alpine:edge AS builder
RUN apk add --no-cache crystal shards libc-dev \
    yaml-dev libxml2-dev sqlite-dev zlib-dev openssl-dev \
    sqlite-static zlib-static openssl-libs-static
WORKDIR /invidious
COPY ./shard.yml ./shard.yml
RUN shards update && shards install
COPY ./src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./.git/ ./.git/
RUN crystal build --static --release --warnings all --error-on-warnings \
# TODO: Remove next line, see https://github.com/crystal-lang/crystal/issues/7946
    -Dmusl \
    ./src/invidious.cr

FROM alpine:latest
RUN apk add --no-cache imagemagick ttf-opensans
WORKDIR /invidious
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious
COPY ./assets/ ./assets/
COPY ./config/config.yml ./config/config.yml
COPY ./config/sql/ ./config/sql/
COPY ./locales/ ./locales/
RUN sed -i 's/host: 127.0.0.1/host: postgres/' config/config.yml
COPY --from=builder /invidious/invidious .
USER invidious
CMD [ "/invidious/invidious" ]
