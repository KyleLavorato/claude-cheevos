BINARY     := cheevos
GO_DIR     := ./go
CMD        := $(GO_DIR)/cmd/cheevos
DEFS_SRC   := ./data/definitions.json
DEFS_DST   := $(GO_DIR)/internal/defs/definitions.json
DIST_DIR   := ./dist

# Strip debug info from release builds.
LDFLAGS_BASE := -s -w

# Platforms to cross-compile for.
PLATFORMS := \
    darwin/amd64 \
    darwin/arm64 \
    linux/amd64  \
    linux/arm64  \
    windows/amd64

# ─── Copy definitions before any build ─────────────────────────────────────
$(DEFS_DST): $(DEFS_SRC)
	cp $(DEFS_SRC) $(DEFS_DST)

.PHONY: defs
defs: $(DEFS_DST)

# ─── Production build for current platform into dist/ ───────────────────────
# Usage:
#   make prod                                          # auto-generates key
#   CHEEVOS_HMAC_KEY=$(cd go && go run ./tools/keygen) make prod  # supply key
.PHONY: prod
prod: defs
	$(eval _KEY := $(or $(CHEEVOS_HMAC_KEY),$(shell cd $(GO_DIR) && go run ./tools/keygen)))
	$(eval _OS   := $(shell go env GOOS))
	$(eval _ARCH := $(shell go env GOARCH))
	$(eval _EXT  := $(if $(filter windows,$(_OS)),.exe,))
	$(eval _OUT  := $(DIST_DIR)/$(BINARY)-$(_OS)-$(_ARCH)$(_EXT))
	@mkdir -p $(DIST_DIR)
	cd $(GO_DIR) && GOOS=$(_OS) GOARCH=$(_ARCH) go build \
		-ldflags "$(LDFLAGS_BASE) -X 'main.hmacSecretRaw=$(_KEY)'" \
		-o ../$(_OUT) ./cmd/cheevos
	@echo "Built $(_OUT) with HMAC key"

# ─── Cross-compile all platforms into dist/ ────────────────────────────────
# Usage:
#   make dist                                          # auto-generates key
#   CHEEVOS_HMAC_KEY=$(cd go && go run ./tools/keygen) make dist  # supply key
.PHONY: dist
dist: defs
	$(eval _KEY := $(or $(CHEEVOS_HMAC_KEY),$(shell cd $(GO_DIR) && go run ./tools/keygen)))
	@mkdir -p $(DIST_DIR)
	@for p in $(PLATFORMS); do \
		OS=$${p%/*}; ARCH=$${p#*/}; \
		OUT=$(DIST_DIR)/$(BINARY)-$$OS-$$ARCH; \
		[ "$$OS" = "windows" ] && OUT="$$OUT.exe"; \
		echo "Building $$OUT..."; \
		cd $(GO_DIR) && GOOS=$$OS GOARCH=$$ARCH go build \
			-ldflags "$(LDFLAGS_BASE) -X 'main.hmacSecretRaw=$(_KEY)'" \
			-o ../$$OUT ./cmd/cheevos; \
		cd ..; \
	done
	@echo "All binaries in $(DIST_DIR)/"

# ─── Create distributable zip (run after dist) ─────────────────────────────
# Bundles everything install.sh needs into dist/cheevos-release.zip.
# The zip unpacks to cheevos/ — users run: unzip cheevos-release.zip && bash cheevos/install.sh
# Usage: make dist-zip  (auto-generates key, or prefix with CHEEVOS_HMAC_KEY=...)
.PHONY: dist-zip
dist-zip: dist
	@echo "Creating dist/cheevos-release.zip..."
	@rm -f $(DIST_DIR)/cheevos-release.zip
	@ZIP_ROOT=cheevos; \
	zip -r $(DIST_DIR)/cheevos-release.zip \
		install.sh \
		uninstall.sh \
		$(DIST_DIR)/$(BINARY)-darwin-amd64 \
		$(DIST_DIR)/$(BINARY)-darwin-arm64 \
		$(DIST_DIR)/$(BINARY)-linux-amd64 \
		$(DIST_DIR)/$(BINARY)-linux-arm64 \
		$(DIST_DIR)/$(BINARY)-windows-amd64.exe \
		hooks/ \
		scripts/ \
		data/definitions.json \
		-x "*.DS_Store" -x "__MACOSX/*"
	@echo "Created $(DIST_DIR)/cheevos-release.zip"
	@echo "  → unzip cheevos-release.zip && bash install.sh"

# ─── Tests ─────────────────────────────────────────────────────────────────
# Usage: make test
.PHONY: test
test: defs
	cd $(GO_DIR) && go test ./...

# ─── Clean ─────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -f $(DEFS_DST)
	rm -rf $(DIST_DIR)/
