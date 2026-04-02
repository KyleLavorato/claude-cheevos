BINARY        := cheevos
ARTIFACT_NAME := claude-cheevos
GO_DIR     := ./go
CMD        := $(GO_DIR)/cmd/cheevos
DIST_DIR   := ./dist
VERSION    ?= dev

# Strip debug info from release builds.
LDFLAGS_BASE := -s -w
LDFLAGS      := $(LDFLAGS_BASE) -X 'main.appVersion=$(VERSION)'

# Platforms to cross-compile for.
PLATFORMS := \
    darwin/amd64 \
    darwin/arm64 \
    linux/amd64  \
    linux/arm64  \
    windows/amd64

# ─── Production build for current platform into dist/ ───────────────────────
# Usage:
#   make prod                                          # auto-generates key
#   CHEEVOS_HMAC_KEY=$(cd go && go run ./tools/keygen) make prod  # supply key
.PHONY: prod
prod:
	$(eval _KEY := $(or $(CHEEVOS_HMAC_KEY),$(shell cd $(GO_DIR) && go run ./tools/keygen)))
	$(eval _OS   := $(shell go env GOOS))
	$(eval _ARCH := $(shell go env GOARCH))
	$(eval _EXT  := $(if $(filter windows,$(_OS)),.exe,))
	$(eval _OUT  := $(DIST_DIR)/$(BINARY)-$(_OS)-$(_ARCH)$(_EXT))
	@mkdir -p $(DIST_DIR)
	cd $(GO_DIR) && GOOS=$(_OS) GOARCH=$(_ARCH) go build \
		-ldflags "$(LDFLAGS) -X 'main.hmacSecretRaw=$(_KEY)'" \
		-o ../$(_OUT) ./cmd/cheevos
	@if [ "$(_OS)" = "darwin" ] && command -v codesign >/dev/null 2>&1; then \
		codesign --force --sign - $(_OUT) 2>/dev/null && echo "Ad-hoc signed $(_OUT)" || true; \
	fi
	@echo "Built $(_OUT) with HMAC key"

# ─── Cross-compile all platforms into dist/ ────────────────────────────────
# Usage:
#   make dist                                          # auto-generates key
#   CHEEVOS_HMAC_KEY=$(cd go && go run ./tools/keygen) make dist  # supply key
.PHONY: dist
dist:
	$(eval _KEY := $(or $(CHEEVOS_HMAC_KEY),$(shell cd $(GO_DIR) && go run ./tools/keygen)))
	@mkdir -p $(DIST_DIR)
	@for p in $(PLATFORMS); do \
		OS=$${p%/*}; ARCH=$${p#*/}; \
		OUT=$(DIST_DIR)/$(BINARY)-$$OS-$$ARCH; \
		[ "$$OS" = "windows" ] && OUT="$$OUT.exe"; \
		echo "Building $$OUT..."; \
		cd $(GO_DIR) && GOOS=$$OS GOARCH=$$ARCH go build \
			-ldflags "$(LDFLAGS) -X 'main.hmacSecretRaw=$(_KEY)'" \
			-o ../$$OUT ./cmd/cheevos; \
		cd ..; \
	done
	@echo "All binaries in $(DIST_DIR)/"

# ─── Create per-platform zips (run after dist) ─────────────────────────────
# Creates one zip per platform. Each zip contains everything install.sh needs:
#   hooks/, scripts/, commands/, data/definitions.json, install.sh, uninstall.sh,
#   and the single platform binary at dist/cheevos-{os}-{arch}[.exe].
# Users download the zip for their platform, unzip it, and run: bash install.sh
# Usage: make dist-zip  (auto-generates key, or prefix with CHEEVOS_HMAC_KEY=...)
.PHONY: dist-zip
dist-zip: dist
	@echo "Creating per-platform zips in $(DIST_DIR)/..."
	@for p in $(PLATFORMS); do \
		OS=$${p%/*}; ARCH=$${p#*/}; \
		BIN=$(DIST_DIR)/$(BINARY)-$$OS-$$ARCH; \
		[ "$$OS" = "windows" ] && BIN="$$BIN.exe"; \
		ZIP=$(DIST_DIR)/$(ARTIFACT_NAME)-$$OS-$$ARCH.zip; \
		echo "Packaging $$ZIP..."; \
		rm -f "$$ZIP"; \
		zip -r "$$ZIP" \
			install.sh \
			uninstall.sh \
			hooks/ \
			scripts/ \
			commands/ \
			data/definitions.json \
			"$$BIN" \
			-x "*.DS_Store" -x "__MACOSX/*"; \
	done
	@echo "Per-platform zips created in $(DIST_DIR)/"
	@echo "  → unzip claude-cheevos-<os>-<arch>.zip && bash install.sh"

# ─── Tests ─────────────────────────────────────────────────────────────────
# Usage: make test
.PHONY: test
test:
	cd $(GO_DIR) && go test ./...

# ─── Clean ─────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -rf $(DIST_DIR)/
