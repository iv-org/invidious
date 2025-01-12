# -----------------------
#  Compilation options
# -----------------------

RELEASE  := 1
STATIC   := 0

NO_DBG_SYMBOLS := 0

# Enable multi-threading.
# Warning: Experimental feature!!
# invidious is not stable when MT is enabled.
MT := 0


FLAGS ?=
CRYSTAL_BIN ?= crystal
SHARDS_BIN ?= shards

# Build flags configuration
ifeq ($(RELEASE), 1)
  FLAGS += --release
endif

ifeq ($(STATIC), 1)
  FLAGS += --static
endif

ifeq ($(MT), 1)
  FLAGS += -Dpreview_mt
endif

ifeq ($(NO_DBG_SYMBOLS), 1)
  FLAGS += --no-debug
else
  FLAGS += --debug
endif

ifeq ($(API_ONLY), 1)
  FLAGS += -Dapi_only
endif

# Development flags
DEVFLAGS := --progress --stats --time

# Output binary name
BINARY_NAME := invidious
BINARY_DEV := $(BINARY_NAME)-dev

# -----------------------
#  Main
# -----------------------

.DEFAULT_GOAL := all

all: $(BINARY_NAME)

get-libs:
	$(SHARDS_BIN) install --production

# TODO: add support for ARM64 via cross-compilation
$(BINARY_NAME): get-libs
	$(CRYSTAL_BIN) build src/$(BINARY_NAME).cr $(FLAGS) --progress --stats --error-trace

run: $(BINARY_NAME)
	./$(BINARY_NAME)


# -----------------------
#  Development
# -----------------------

format:
	$(CRYSTAL_BIN) tool format --check

test:
	$(CRYSTAL_BIN) spec

verify:
	$(CRYSTAL_BIN) build src/$(BINARY_NAME).cr -Dskip_videojs_download \
	  --no-codegen --progress --stats --error-trace

dev-build: get-libs
	$(CRYSTAL_BIN) build src/$(BINARY_NAME).cr $(DEVFLAGS) -o $(BINARY_DEV)

dev-run: dev-build
	INVIDIOUS_CONFIG_FILE=config/config-dev.yml ./$(BINARY_DEV)

# -----------------------
#  (Un)Install
# -----------------------

PREFIX ?= /usr/local
DESTDIR ?=

install: $(BINARY_NAME)
	install -d $(DESTDIR)$(PREFIX)/bin
	install -m 755 $(BINARY_NAME) $(DESTDIR)$(PREFIX)/bin/

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/$(BINARY_NAME)

# -----------------------
#  Cleaning
# -----------------------

clean:
	rm -f $(BINARY_NAME) $(BINARY_DEV)

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
	@echo "  $(BINARY_NAME)   Build Invidious"
	@echo "  run              Launch Invidious"
	@echo ""
	@echo "  format           Run the Crystal formatter"
	@echo "  test             Run tests"
	@echo "  verify           Just make sure that the code compiles, but without"
	@echo "                   generating any binaries. Useful to search for errors"
	@echo ""
	@echo "  install          Install Invidious to system"
	@echo "  uninstall        Remove Invidious from system"
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
	@echo "Installation options:"
	@echo "  PREFIX           Installation prefix             (Default: /usr/local)"
	@echo "  DESTDIR          Destination directory           (Default: empty)"

# No targets generates an output named after themselves
.PHONY: all get-libs build run
.PHONY: format test verify dev-build dev-run
.PHONY: install uninstall clean distclean help
