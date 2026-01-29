# Contributing to Terminal Timer (tt) CLI

## Development Setup

### Prerequisites

- [Rust](https://rustup.rs/) (1.70+)
- Git

### Clone and Build

```bash
git clone https://github.com/EricLBaker/rust_cli_timer.git
cd rust_cli_timer

# Build debug version
cargo build

# Build release version
cargo build --release

# Install locally for testing
make install
```

### Project Structure

```
rust_cli_timer/
├── src/
│   └── main.rs          # Main application code
├── sounds/              # Audio files for alerts
├── assets/              # Images for README
├── scripts/
│   └── bump-version.sh  # Version bump automation
├── install.sh           # Unix installer
├── install.ps1          # Windows installer
├── uninstall.sh         # Unix uninstaller
├── uninstall.ps1        # Windows uninstaller
├── Cargo.toml           # Rust dependencies
└── Makefile             # Build automation
```

<br>

## Makefile Commands

| Command        | Description                         |
| -------------- | ----------------------------------- |
| `make build`   | Build release binary                |
| `make install` | Build and install to `~/.local/bin` |
| `make version` | Show current version                |
| `make clean`   | Remove timer database               |

<br>

## Release Process

### Automated Release (Recommended)

The Makefile provides automated version bumping and release:

```bash
# Patch release (1.0.3 → 1.0.4)
make release-patch

# Minor release (1.0.3 → 1.1.0)
make release-minor

# Major release (1.0.3 → 2.0.0)
make release-major
```

This will:

1. Bump the version in `Cargo.toml`
2. Update `Cargo.lock`
3. Commit the version change
4. Create a git tag (e.g., `v1.0.4`)
5. Push to `main` branch
6. Push the tag to trigger CI/CD

### Manual Version Bump

If you need to bump the version without releasing:

```bash
make bump-patch   # or bump-minor, bump-major
```

### Legacy Manual Release

```bash
# Edit Cargo.toml version manually, then:
make release v=1.0.5
```

<br>

## CI/CD Pipeline

### GitHub Actions Workflow

When a new tag is pushed (e.g., `v1.0.4`), GitHub Actions automatically:

1. **Builds binaries** for all platforms:
   - `timer_cli-macos-x86_64` (Intel Mac)
   - `timer_cli-macos-aarch64` (Apple Silicon)
   - `timer_cli-linux-x86_64`
   - `timer_cli-windows-x86_64.exe`

2. **Creates a GitHub Release** with all binaries attached

3. **Users can then update** via:
   - `tt -u` to check for updates
   - Or, re-running the install script

### Workflow File

The CI/CD configuration is in `.github/workflows/release.yml`.

<br>

## Testing

### Local Testing

```bash
# Run with cargo
cargo run -- 5s "Test timer"

# Test installed version
tt 5s "Test timer"

# Test specific features
tt -l              # Logs/History
tt -a              # Active timers
tt -u              # Update check
tt -v              # Version
tt 10s -f          # Foreground mode
```

### Cross-Platform Testing

- **macOS**: Native development
- **Windows**: Test in PowerShell and Git Bash
- **Linux**: Test in native terminal or WSL

<br>

## Code Style

- Follow Rust idioms and conventions
- Use `cargo fmt` before committing
- Run `cargo clippy` to check for issues

```bash
cargo fmt
cargo clippy
```

<br>

## Pull Request Process

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes
4. Run tests and linting
5. Commit with clear messages
6. Push and create a Pull Request

<br>

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
