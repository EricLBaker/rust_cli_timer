INSTALL_DIR := $(HOME)/.local/bin
BINARY := timer_cli

build:
	cargo build --release

# Install locally (for development) - builds and copies to ~/.local/bin
install: build
	@mkdir -p $(INSTALL_DIR)
	@cp target/release/$(BINARY) $(INSTALL_DIR)/$(BINARY)
	@echo "✓ Installed $(BINARY) to $(INSTALL_DIR)"

# Install via cargo (adds to ~/.cargo/bin instead)
cargo-install:
	cargo install --path .

# Upgrade from latest GitHub release
upgrade:
	@curl -fsSL https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.sh | bash

clean:
	rm -f /tmp/timer_cli.db

release:
	git checkout main
	git pull origin main
	git tag v$(v)
	git push origin v$(v)