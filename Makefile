INSTALL_DIR := $(HOME)/.local/bin
BINARY := timer_cli

# Get current version from Cargo.toml
VERSION := $(shell grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)"/\1/')

build:
	cargo build --release

# Install locally (for development) - builds and copies to ~/.local/bin
install: build
	@mkdir -p $(INSTALL_DIR)
	@cp target/release/$(BINARY) $(INSTALL_DIR)/$(BINARY)
	@echo "✓ Installed $(BINARY) to $(INSTALL_DIR)"
	@if ! echo "$$PATH" | grep -q "$(INSTALL_DIR)"; then \
		echo ""; \
		echo "⚠ $(INSTALL_DIR) is not in PATH. Run:"; \
		echo "  export PATH=\"$(INSTALL_DIR):$$PATH\""; \
	fi

# Clean reinstall - removes old binary, cleans db, rebuilds and installs
reinstall:
	@echo "🧹 Removing old binary..."
	@rm -f $(INSTALL_DIR)/$(BINARY)
	@rm -f /tmp/timer_cli.db
	@echo "🔨 Building..."
	@cargo build --release
	@mkdir -p $(INSTALL_DIR)
	@cp target/release/$(BINARY) $(INSTALL_DIR)/$(BINARY)
	@echo "✓ Clean reinstall complete"
	@echo ""
	@echo "Run this to use immediately:"
	@echo "  export PATH=\"$(INSTALL_DIR):\$$PATH\""

# Install via cargo (adds to ~/.cargo/bin instead)
cargo-install:
	cargo install --path .

# Upgrade from latest GitHub release
upgrade:
	@curl -fsSL https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.sh | bash

clean:
	rm -f /tmp/timer_cli.db

# Show current version
version:
	@echo "Current version: $(VERSION)"

# Bump patch version (1.0.0 -> 1.0.1)
bump-patch:
	@./scripts/bump-version.sh patch

# Bump minor version (1.0.0 -> 1.1.0)
bump-minor:
	@./scripts/bump-version.sh minor

# Bump major version (1.0.0 -> 2.0.0)
bump-major:
	@./scripts/bump-version.sh major

# Release with automatic version bump
# Usage: make release-patch  OR  make release-minor  OR  make release-major
release-patch: bump-patch release-current
release-minor: bump-minor release-current
release-major: bump-major release-current

# Release current version (after manual or scripted version bump)
release-current:
	@NEW_VERSION=$$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)"/\1/'); \
	echo "📦 Releasing v$$NEW_VERSION..."; \
	git add Cargo.toml Cargo.lock; \
	git commit -m "chore: bump version to $$NEW_VERSION" || true; \
	git tag -a "v$$NEW_VERSION" -m "Release v$$NEW_VERSION"; \
	git push origin main; \
	git push origin "v$$NEW_VERSION"; \
	echo "✓ Released v$$NEW_VERSION"

# Legacy release (manual version)
release:
	git checkout main
	git pull origin main
	git tag v$(v)
	git push origin v$(v)