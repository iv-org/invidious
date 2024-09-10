FROM crystallang/crystal:1.12.1-alpine AS builder

RUN apk add --no-cache sqlite-static yaml-static

ARG release

WORKDIR /invidious
COPY ./services/invidious/shard.yml ./shard.yml
COPY ./services/invidious/shard.lock ./shard.lock
RUN shards install --production

COPY ./services/invidious/src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./services/invidious/.git/ ./.git/
RUN sed -i '/worktree/d' .git/config

# Required for fetching player dependencies
COPY ./services/invidious/scripts/ ./scripts/
COPY ./services/invidious/assets/ ./assets/
COPY ./services/invidious/videojs-dependencies.yml ./videojs-dependencies.yml

RUN crystal spec --warnings all \
    --link-flags "-lxml2 -llzma"    
RUN if [[ "${release}" == 1 ]] ; then \
        crystal build ./src/invidious.cr \
        --release \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    else \
        crystal build ./src/invidious.cr \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    fi

FROM alpine:3.18
RUN apk add --no-cache rsvg-convert ttf-opensans tini
WORKDIR /invidious
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious
COPY --chown=invidious ./services/invidious/config/config.* ./config/
RUN mv -n config/config.example.yml config/config.yml
RUN sed -i 's/host: \(127.0.0.1\|localhost\)/host: invidious-db/' config/config.yml
COPY ./services/invidious/config/sql/ ./config/sql/
COPY ./services/invidious/locales/ ./locales/
COPY --from=builder /invidious/assets ./assets/
COPY --from=builder /invidious/invidious .
RUN chmod o+rX -R ./assets ./config ./locales

EXPOSE 3000
USER invidious
ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/invidious/invidious" ]
