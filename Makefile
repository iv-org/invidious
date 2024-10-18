# -----------------------
#  Compilation options
# -----------------------

RELEASE  := 1
STATIC   := 0

NO_DBG_SYMBOLS := 0


FLAGS ?=
LDFLAGS ?=


ifeq ($(RELEASE), 1)
  FLAGS += --release
endif

ifeq ($(STATIC), 1)
  FLAGS += --static
  LDFLAGS += -static
endif


ifeq ($(NO_DBG_SYMBOLS), 1)
  FLAGS += --no-debug
else
  FLAGS += --debug
endif

ifeq ($(API_ONLY), 1)
  FLAGS += -Dapi_only
endif


#FLAGS += --progress --stats --error-trace


LIBS_SSL = $(shell command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libssl || printf %s '-lssl -lcrypto')
LIBS_CRYPTO = $(shell command -v pkg-config > /dev/null && pkg-config --libs --silence-errors libcrypto || printf %s '-lcrypto')


# -----------------------
#  Main
# -----------------------

all: invidious

get-libs:
	shards install --production

invidious: get-libs
	crystal build src/invidious.cr $(FLAGS)

run: invidious
	./invidious


# -----------------------
#  Cross-compilation (Host)
# -----------------------

# Supported cross-sompilation targets:
#  - amd64-glibc (x86_64-linux-gnu)
#  - amd64-musl  (x86_64-linux-musl)
#  - arm64-glibc (aarch64-linux-gnu)
#  - arm64-musl  (aarch64-linux-musl)
#  - armhf       (arm-linux-gnueabihf)

invidious-cross-amd64-glibc:
	crystal build src/invidious.cr $(FLAGS) -Duse_pcre -Dskip_videojs_download \
		--cross-compile --target='x86_64-linux-gnu' -o invidious-amd64-glibc

invidious-cross-amd64-musl:
	crystal build src/invidious.cr $(FLAGS) -Duse_pcre -Dskip_videojs_download \
		--cross-compile --target='x86_64-linux-musl' -o invidious-amd64-musl


invidious-cross-arm64-glibc:
	crystal build src/invidious.cr $(FLAGS) -Duse_pcre -Dskip_videojs_download \
		--cross-compile --target='aarch64-linux-gnu' -o invidious-arm64-glibc

invidious-cross-arm64-musl:
	crystal build src/invidious.cr $(FLAGS) -Duse_pcre -Dskip_videojs_download \
		--cross-compile --target='aarch64-linux-musl' -o invidious-arm64-musl


invidious-cross-armhf:
	crystal build src/invidious.cr $(FLAGS) -Duse_pcre -Dskip_videojs_download \
		--cross-compile --target='arm-linux-gnueabihf' -o invidious-armhf


# Build everything at once
invidious-cross-all: invidious-cross-amd64-glibc
invidious-cross-all: invidious-cross-amd64-musl
invidious-cross-all: invidious-cross-arm64-glibc
invidious-cross-all: invidious-cross-arm64-musl
invidious-cross-all: invidious-cross-armhf


# -----------------------
#  Cross-compilation (Target)
# -----------------------

invidious-amd64-glibc:
invidious-arm64-glibc:
	cc "$@.o" -o "$@" -rdynamic $(LDFLAGS) \
		-lyaml -lxml2 -lsqlite3 -lz -llzma $(LIBS_SSL) $(LIBS_CRYPTO) \
		-lpcre -lm -lgc -lpthread -levent -lrt -lpthread -ldl

invidious-amd64-musl:
invidious-arm64-musl:
	cc "$@.o" -o "$@" -rdynamic $(LDFLAGS) \
		-lyaml -lxml2 -lsqlite3 -lz -llzma $(LIBS_SSL) $(LIBS_CRYPTO) \
		-lpcre -lgc -levent

invidious-armhf:
	cc "$@.o" -o "$@" -rdynamic $(LDFLAGS) \
		-lyaml -lxml2 -lsqlite3 -lz -llzma $(LIBS_SSL) $(LIBS_CRYPTO) \
		-lpcre -lm -lgc -lpthread -levent -lpthread -ldl


# -----------------------
#  Development
# -----------------------

format:
	crystal tool format

test:
	crystal spec

verify:
	crystal build src/invidious.cr -Dskip_videojs_download \
	  --no-codegen --progress --stats --error-trace


# -----------------------
#  (Un)Install
# -----------------------

# TODO


# -----------------------
#  Cleaning
# -----------------------

clean:
	rm -f invidious invidious-*

distclean: clean
	rm -rf libs
	rm -rf ~/.cache/{crystal,shards}


# -----------------------
#  Help page
# -----------------------

help:
	@echo "Targets available in this Makefile:"
	@echo ""
	@echo "  get-libs         Fetch Crystal libraries"
	@echo "  invidious        Build Invidious"
	@echo "  run              Launch Invidious"
	@echo ""
	@echo "  format           Run the Crystal formatter"
	@echo "  test             Run tests"
	@echo "  verify           Just make sure that the code compiles, but without"
	@echo "                   generating any binaries. Useful to search for errors"
	@echo ""
	@echo "  clean            Remove build artifacts"
	@echo "  distclean        Remove build artifacts and libraries"
	@echo ""
	@echo ""
	@echo "Build options available for this Makefile:"
	@echo ""
	@echo "  RELEASE          Make a release build            (Default: 1)"
	@echo "  STATIC           Link libraries statically       (Default: 0)"
	@echo ""
	@echo "  API_ONLY         Build invidious without a GUI   (Default: 0)"
	@echo "  NO_DBG_SYMBOLS   Strip debug symbols             (Default: 0)"
	@echo ""
	@echo ""
	@echo "Cross-compiling"
	@echo ""
	@echo "To cross compile, run 'make invidious-cross-{arch}' on the build host,"
	@echo "then move the .o file to the target host and run 'make invidious-{arch}'"
	@echo "on there (requires crystal and all the dependencies to be installed)"
	@echo ""
	@echo "Note: If 'STATIC=1' was used on the build host, then it MUST be used on"
	@echo "      'the target host too!"
	@echo ""
	@echo "Supported cross-sompilation archs:"
	@echo " - amd64-glibc (x86_64-linux-gnu)"
	@echo " - amd64-musl  (x86_64-linux-musl)"
	@echo " - arm64-glibc (aarch64-linux-gnu)"
	@echo " - arm64-musl  (aarch64-linux-musl)"
	@echo " - armhf       (arm-linux-gnueabihf)"


# No targets generates an output named after themselves
.PHONY: all get-libs build amd64 run
.PHONY: format test verify clean distclean help
.PHONY: invidious-cross-amd64-glibc invidious-cross-amd64-musl
.PHONY: invidious-cross-arm64-glibc invidious-cross-arm64-musl
.PHONY: invidious-cross-armhf
