#!/bin/sh
set -e

# Timer CLI Installer
# Usage: curl -sSf https://raw.githubusercontent.com/YOUR_USERNAME/rust_cli_timer/main/install.sh | sh

REPO="YOUR_USERNAME/rust_cli_timer"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

# Detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case "$OS" in
        darwin)
            case "$ARCH" in
                x86_64) PLATFORM="macos-x86_64" ;;
                arm64)  PLATFORM="macos-aarch64" ;;
                *)      echo "Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            ;;
        linux)
            case "$ARCH" in
                x86_64) PLATFORM="linux-x86_64" ;;
                *)      echo "Unsupported architecture: $ARCH"; exit 1 ;;
            esac
            ;;
        *)
            echo "Unsupported OS: $OS"
            echo "For Windows, download from: https://github.com/$REPO/releases"
            exit 1
            ;;
    esac
}

# Get latest release version
get_latest_version() {
    curl -sSf "https://api.github.com/repos/$REPO/releases/latest" | 
        grep '"tag_name":' | 
        sed -E 's/.*"([^"]+)".*/\1/'
}

main() {
    echo "🕐 Timer CLI Installer"
    echo ""

    detect_platform
    echo "Detected platform: $PLATFORM"

    VERSION=$(get_latest_version)
    if [ -z "$VERSION" ]; then
        echo "Error: Could not determine latest version"
        exit 1
    fi
    echo "Latest version: $VERSION"

    DOWNLOAD_URL="https://github.com/$REPO/releases/download/$VERSION/timer_cli-$PLATFORM"
    
    echo "Downloading from: $DOWNLOAD_URL"
    
    # Create install directory
    mkdir -p "$INSTALL_DIR"
    
    # Download binary
    curl -sSfL "$DOWNLOAD_URL" -o "$INSTALL_DIR/timer_cli"
    chmod +x "$INSTALL_DIR/timer_cli"

    echo ""
    echo "✅ Timer CLI installed to $INSTALL_DIR/timer_cli"
    echo ""
    
    # Check if install dir is in PATH
    case ":$PATH:" in
        *":$INSTALL_DIR:"*) 
            echo "🎉 You're all set! Run 'timer_cli --help' to get started."
            ;;
        *)
            echo "⚠️  Add $INSTALL_DIR to your PATH:"
            echo ""
            echo "    echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.bashrc"
            echo "    # or for zsh:"
            echo "    echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> ~/.zshrc"
            echo ""
            echo "Then restart your terminal or run: source ~/.bashrc"
            ;;
    esac
}

main
