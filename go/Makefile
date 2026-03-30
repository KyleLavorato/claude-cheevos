BINARY     := cheevos
CMD        := ./cmd/cheevos
DEFS_SRC   := ../data/definitions.json
DEFS_DST   := ./internal/defs/definitions.json
# dist/ lives at the repo root so install.sh (also at repo root) can find binaries.
DIST_DIR   := ../dist

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

# ─── Local dev build (current platform, no HMAC key injection) ─────────────
.PHONY: build
build: defs
	go build \
		-ldflags "$(LDFLAGS_BASE) -X 'main.hmacSecretRaw='" \
		-o $(BINARY) $(CMD)
	@echo "Built ./$(BINARY)"

# ─── Production build (requires CHEEVOS_HMAC_KEY env var) ──────────────────
# Generate key: go run ./tools/keygen
# Then: CHEEVOS_HMAC_KEY=$(go run ./tools/keygen) make prod
.PHONY: prod
prod: defs
	@if [ -z "$(CHEEVOS_HMAC_KEY)" ]; then \
		echo "ERROR: CHEEVOS_HMAC_KEY is not set."; \
		echo "       Run: CHEEVOS_HMAC_KEY=\$$(go run ./tools/keygen) make prod"; \
		exit 1; \
	fi
	go build \
		-ldflags "$(LDFLAGS_BASE) -X 'main.hmacSecretRaw=$(CHEEVOS_HMAC_KEY)'" \
		-o $(BINARY) $(CMD)
	@echo "Built ./$(BINARY) with HMAC key"

# ─── Cross-compile all platforms ───────────────────────────────────────────
# Requires CHEEVOS_HMAC_KEY.
.PHONY: dist
dist: defs
	@if [ -z "$(CHEEVOS_HMAC_KEY)" ]; then \
		echo "ERROR: CHEEVOS_HMAC_KEY is not set."; \
		echo "       Run: CHEEVOS_HMAC_KEY=\$$(go run ./tools/keygen) make dist"; \
		exit 1; \
	fi
	@mkdir -p $(DIST_DIR)
	@for p in $(PLATFORMS); do \
		OS=$${p%/*}; ARCH=$${p#*/}; \
		OUT=$(DIST_DIR)/$(BINARY)-$$OS-$$ARCH; \
		[ "$$OS" = "windows" ] && OUT="$$OUT.exe"; \
		echo "Building $$OUT..."; \
		GOOS=$$OS GOARCH=$$ARCH go build \
			-ldflags "$(LDFLAGS_BASE) -X 'main.hmacSecretRaw=$(CHEEVOS_HMAC_KEY)'" \
			-o $$OUT $(CMD); \
	done
	@echo "All binaries in $(DIST_DIR)/"

# ─── Tests ─────────────────────────────────────────────────────────────────
.PHONY: test
test: defs
	go test ./...

# ─── Clean ─────────────────────────────────────────────────────────────────
.PHONY: clean
clean:
	rm -f $(BINARY) $(DEFS_DST)
	rm -rf $(DIST_DIR)/
