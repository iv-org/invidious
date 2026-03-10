# https://github.com/openssl/openssl/releases/tag/openssl-3.5.2
ARG OPENSSL_VERSION='3.5.2'
ARG OPENSSL_SHA256='c53a47e5e441c930c3928cf7bf6fb00e5d129b630e0aa873b08258656e7345ec'

FROM crystallang/crystal:1.19.1-alpine AS dependabot-crystal

# We compile openssl ourselves due to a memory leak in how crystal interacts
# with openssl
# Reference: https://github.com/iv-org/invidious/issues/1438#issuecomment-3087636228
FROM dependabot-crystal AS openssl-builder
RUN apk add --no-cache curl perl linux-headers

WORKDIR /

ARG OPENSSL_VERSION
ARG OPENSSL_SHA256
RUN curl -Ls "https://github.com/openssl/openssl/releases/download/openssl-${OPENSSL_VERSION}/openssl-${OPENSSL_VERSION}.tar.gz" --output openssl-${OPENSSL_VERSION}.tar.gz
RUN echo "${OPENSSL_SHA256}  openssl-${OPENSSL_VERSION}.tar.gz" | sha256sum -c
RUN tar -xzvf openssl-${OPENSSL_VERSION}.tar.gz

RUN cd openssl-${OPENSSL_VERSION} && ./Configure --openssldir=/etc/ssl && make -j$(nproc)

FROM dependabot-crystal AS builder

RUN apk add --no-cache sqlite-static yaml-static
RUN apk del openssl-dev openssl-libs-static

ARG release

WORKDIR /invidious
COPY ./shard.yml ./shard.yml
COPY ./shard.lock ./shard.lock
RUN shards install --production

COPY ./src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./.git/ ./.git/

# Required for fetching player dependencies
COPY ./scripts/ ./scripts/
COPY ./assets/ ./assets/
COPY ./videojs-dependencies.yml ./videojs-dependencies.yml

RUN crystal spec --warnings all \
    --link-flags "-lxml2 -llzma"    

ARG OPENSSL_VERSION
COPY --from=openssl-builder /openssl-${OPENSSL_VERSION} /openssl-${OPENSSL_VERSION}

RUN --mount=type=cache,target=/root/.cache/crystal if [[ "${release}" == 1 ]] ; then \
        PKG_CONFIG_PATH=/openssl-${OPENSSL_VERSION} \
        crystal build ./src/invidious.cr \
        --release \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    else \
        PKG_CONFIG_PATH=/openssl-${OPENSSL_VERSION} \
        crystal build ./src/invidious.cr \
        --static --warnings all \
        --link-flags "-lxml2 -llzma"; \
    fi

FROM alpine:3.23
RUN apk add --no-cache rsvg-convert ttf-opensans tini tzdata
WORKDIR /invidious
RUN addgroup -g 1000 -S invidious && \
    adduser -u 1000 -S invidious -G invidious
COPY --chown=invidious ./config/config.* ./config/
RUN mv -n config/config.example.yml config/config.yml
RUN sed -i 's/host: \(127.0.0.1\|localhost\)/host: invidious-db/' config/config.yml
COPY ./config/sql/ ./config/sql/
COPY ./locales/ ./locales/
COPY --from=builder /invidious/assets ./assets/
COPY --from=builder /invidious/invidious .
RUN chmod o+rX -R ./assets ./config ./locales

EXPOSE 3000
USER invidious
ENTRYPOINT ["/sbin/tini", "--"]
CMD [ "/invidious/invidious" ]
