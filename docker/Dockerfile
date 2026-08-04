# https://github.com/openssl/openssl/releases/tag/openssl-3.6.3
ARG OPENSSL_VERSION='3.6.3'
ARG OPENSSL_SHA256='243a86649cf6f23eeb6a2ff2456e09e5d77dd9018a54d3d96b0c6bdd6ba6c7f1'

FROM 84codes/crystal:1.20.3-alpine AS dependabot-crystal

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

# 2026-08-04:
#
# `-no-pie` has been added to link flags due to missing debug information
# when compiling Invidious using `--static` (because `--static` enables PIE, but
# with PIE enabled, Crystal cannot provide debug information when an error
# in Invidious appears)
# References:
# - https://forum.crystal-lang.org/t/gcc-15-on-alpine-linux-changes-static-to-imply-pie-i-e-static-pie/9074/5?u=fijxu
# - https://github.com/crystal-lang/distribution-scripts/issues/445
# - https://github.com/84codes/crystal-packages/issues/41
#
# `-no-pie` can be removed once it's fixed.
RUN --mount=type=cache,target=/root/.cache/crystal if [[ "${release}" == 1 ]] ; then \
        PKG_CONFIG_PATH=/openssl-${OPENSSL_VERSION} \
        crystal build ./src/invidious.cr \
        --release \
        --static --warnings all \
        --link-flags "-lxml2 -llzma -no-pie"; \
    else \
        PKG_CONFIG_PATH=/openssl-${OPENSSL_VERSION} \
        crystal build ./src/invidious.cr \
        --static --warnings all \
        --link-flags "-lxml2 -llzma -no-pie";  \
    fi

FROM alpine:3.24
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
