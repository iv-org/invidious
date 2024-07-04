# -----------------------
#  Compilation options
# -----------------------

RELEASE  := 1
STATIC   := 0

NO_DBG_SYMBOLS := 0


FLAGS ?=


ifeq ($(RELEASE), 1)
  FLAGS += --release
endif

ifeq ($(STATIC), 1)
  FLAGS += --static
endif


ifeq ($(NO_DBG_SYMBOLS), 1)
  FLAGS += --no-debug
else
  FLAGS += --debug
endif

ifeq ($(API_ONLY), 1)
  FLAGS += -Dapi_only
endif


# -----------------------
#  Main
# -----------------------

all: invidious

get-libs:
	shards install --production

# TODO: add support for ARM64 via cross-compilation
invidious: get-libs
	crystal build src/invidious.cr $(FLAGS) --progress --stats --error-trace


run: invidious
	./invidious


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
	rm invidious

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



# No targets generates an output named after themselves
.PHONY: all get-libs build amd64 run
.PHONY: format test verify clean distclean help
