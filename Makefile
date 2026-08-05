# -----------------------------------------
# Makefile – Ebitengine project builder
# -----------------------------------------

PROJECT = ebitenginedemo

BIN_DIR     = bin
DIST_DIR    = dist
WASM_NAME   = game.wasm
OUTPUT_BIN  = $(BIN_DIR)/$(PROJECT)
OUTPUT_WASM = $(DIST_DIR)/$(WASM_NAME)
OUTPUT_JS   = $(DIST_DIR)/wasm_exec.js
OUTPUT_ZIP  = $(PROJECT)-$(VERSION).html.zip

VERSION_FILE = .version
INDEX_HTML_URL = https://git.teletypegames.org/tools/ebitengine-tools/raw/branch/master/web/index.html

all: build

build:
	@mkdir -p $(BIN_DIR)
	go build -o $(OUTPUT_BIN) .

wasm:
	@mkdir -p $(DIST_DIR)
	GOOS=js GOARCH=wasm go build -o $(OUTPUT_WASM) .
	cp "$$(go env GOROOT)/lib/wasm/wasm_exec.js" $(OUTPUT_JS)

export: wasm
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION not set!"; exit 1; \
	fi
	@echo "==> Downloading index.html"
	curl -sSL $(INDEX_HTML_URL) -o $(DIST_DIR)/index.html
	@echo "==> Packaging HTML/WASM for $(VERSION)"
	zip -r $(OUTPUT_ZIP) -j $(DIST_DIR)/$(WASM_NAME) $(DIST_DIR)/wasm_exec.js $(DIST_DIR)/index.html
	@echo "==> Cleaning temporary files"
	rm -f $(DIST_DIR)/$(WASM_NAME) $(DIST_DIR)/wasm_exec.js $(DIST_DIR)/index.html

# --- native binaries (lásd: teletypegames/NOTES_BINARY_PLAN.md) -------------
# win-x86 / win-x64: pure Go cross-compile (Windowson nem kell cgo)
# linux-x64: cgo build, linux/amd64 hoston fut (builder image, X11/GL dev libekkel)
BINARY_TARGETS = win-x86 win-x64 linux-x64

binaries:
	@if [ -z "$(VERSION)" ]; then \
		echo "ERROR: VERSION not set!"; exit 1; \
	fi
	@for target in $(BINARY_TARGETS); do \
		$(MAKE) binary-$$target VERSION=$(VERSION) || exit 1; \
	done

binary-win-x86:
	@$(MAKE) binary-build VERSION=$(VERSION) B_GOOS=windows B_GOARCH=386 B_CGO=0 B_EXT=.exe B_TARGET=win-x86

binary-win-x64:
	@$(MAKE) binary-build VERSION=$(VERSION) B_GOOS=windows B_GOARCH=amd64 B_CGO=0 B_EXT=.exe B_TARGET=win-x64

binary-linux-x64:
	@$(MAKE) binary-build VERSION=$(VERSION) B_GOOS=linux B_GOARCH=amd64 B_CGO=1 B_EXT= B_TARGET=linux-x64

# belső helper: egy target buildje + zip egyetlen gyökérmappával
# (a zipet unixos zip készíti, így a végrehajtási bit megmarad)
binary-build:
	@set -e; \
	PKG_DIR="$(PROJECT)-$(VERSION)-$(B_TARGET)"; \
	echo "==> Building $$PKG_DIR"; \
	rm -rf "$$PKG_DIR" "$$PKG_DIR.zip"; \
	mkdir -p "$$PKG_DIR"; \
	CGO_ENABLED=$(B_CGO) GOOS=$(B_GOOS) GOARCH=$(B_GOARCH) go build -o "$$PKG_DIR/$(PROJECT)$(B_EXT)" .; \
	if [ -f LICENSE ]; then cp LICENSE "$$PKG_DIR/"; fi; \
	if [ -f README.md ]; then cp README.md "$$PKG_DIR/"; fi; \
	zip -r "$$PKG_DIR.zip" "$$PKG_DIR" >/dev/null; \
	rm -rf "$$PKG_DIR"; \
	echo "==> $$PKG_DIR.zip kesz"

watch:
	fswatch -o . | while read; do make build; done

clean:
	rm -rf $(BIN_DIR) $(DIST_DIR)

ci-version:
	@if [ -f metadata.json ]; then \
		VERSION=$$(jq -r '.version' metadata.json); \
	else \
		VERSION=$$(git rev-parse --short HEAD); \
	fi; \
	BRANCH=$$(git rev-parse --abbrev-ref HEAD); \
	if [ "$$BRANCH" != "main" ] && [ "$$BRANCH" != "master" ]; then \
		VERSION="dev-$$VERSION-$$BRANCH"; \
	fi; \
	echo $$VERSION > $(VERSION_FILE)

ci-export:
	@VERSION=$$(cat $(VERSION_FILE)); \
	$(MAKE) export VERSION=$$VERSION

ci-binaries:
	@VERSION=$$(cat $(VERSION_FILE)); \
	$(MAKE) binaries VERSION=$$VERSION

ci-upload:
	@VERSION=$$(cat $(VERSION_FILE)); \
	FILE="$(PROJECT)-$$VERSION.html.zip"; \
	META_SRC="metadata.json"; \
	META_DST="$(PROJECT)-$$VERSION.metadata.json"; \
	BINS=$$(ls $(PROJECT)-$$VERSION-*.zip 2>/dev/null || true); \
	cp $$META_SRC $$META_DST; \
	for f in $$FILE $$META_DST $$BINS; do \
		curl -fsS -H "X-Update-Secret: $(UPDATE_SECRET)" \
			-F "file=@$$f" \
			"$(UPDATE_SERVER)/build/upload?name=$(PROJECT)&version=$$VERSION" || exit 1; \
	done

ci-publish:
	@VERSION=$$(cat $(VERSION_FILE)); \
	curl -fsS -X POST -H "X-Update-Secret: $(UPDATE_SECRET)" "$(UPDATE_SERVER)/build/publish?name=$(PROJECT)&platform=ebitengine&version=$$VERSION"

.PHONY: all build wasm export watch clean binaries binary-win-x86 binary-win-x64 binary-linux-x64 binary-build ci-version ci-export ci-binaries ci-upload ci-publish