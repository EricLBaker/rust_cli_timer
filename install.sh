#!/bin/bash
set -euo pipefail

# Terminal Timer (tt) CLI Installer for macOS, Linux, and Windows (WSL/Git Bash)
# Usage: curl -fsSL https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.sh | bash
#
# For native Windows (PowerShell):
#   iwr -useb https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.ps1 | iex

# ============================================================================
# Configuration
# ============================================================================

REPO="EricLBaker/rust_cli_timer"
BINARY_NAME="timer_cli"
INSTALL_DIR="${TIMER_CLI_INSTALL_DIR:-$HOME/.local/bin}"
CARGO_BIN="$HOME/.cargo/bin"
BUILD_FROM_SOURCE="${TIMER_CLI_BUILD_FROM_SOURCE:-0}"

# ============================================================================
# Colors (Tokyo Night theme)
# ============================================================================

BOLD='\033[1m'
SUCCESS='\033[38;2;158;206;106m'    # Green  #9ece6a
WARN='\033[38;2;187;154;247m'       # Purple #bb9af7
ERROR='\033[38;2;247;118;142m'      # Pink   #f7768e
INFO='\033[38;2;122;162;247m'       # Blue   #7aa2f7
ACCENT='\033[38;2;224;175;104m'     # Yellow #e0af68
MUTED='\033[38;2;86;95;137m'        # Gray   #565f89
NC='\033[0m'

log_success() { echo -e "${SUCCESS}✓${NC} $1"; }
log_warn() { echo -e "${WARN}→${NC} $1"; }
log_error() { echo -e "${ERROR}✗${NC} $1"; }
log_info() { echo -e "${INFO}i${NC} $1"; }

# ============================================================================
# Temp file management
# ============================================================================

TMPFILES=()
cleanup_tmpfiles() {
    for f in "${TMPFILES[@]:-}"; do
        rm -f "$f" 2>/dev/null || true
    done
}
trap cleanup_tmpfiles EXIT

mktempfile() {
    local f
    f="$(mktemp)"
    TMPFILES+=("$f")
    echo "$f"
}

# ============================================================================
# Downloader (curl or wget)
# ============================================================================

DOWNLOADER=""
detect_downloader() {
    if command -v curl &> /dev/null; then
        DOWNLOADER="curl"
        return 0
    fi
    if command -v wget &> /dev/null; then
        DOWNLOADER="wget"
        return 0
    fi
    log_error "Missing downloader (curl or wget required)"
    exit 1
}

download_file() {
    local url="$1"
    local output="$2"
    [[ -z "$DOWNLOADER" ]] && detect_downloader
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL --proto '=https' --tlsv1.2 --retry 3 -o "$output" "$url"
    else
        wget -q --https-only --tries=3 -O "$output" "$url"
    fi
}

fetch_url() {
    local url="$1"
    [[ -z "$DOWNLOADER" ]] && detect_downloader
    if [[ "$DOWNLOADER" == "curl" ]]; then
        curl -fsSL --proto '=https' --tlsv1.2 "$url" 2>/dev/null
    else
        wget -qO- --https-only "$url" 2>/dev/null
    fi
}

# ============================================================================
# Platform detection
# ============================================================================

OS=""
ARCH=""
PLATFORM=""

detect_platform() {
    local os_raw arch_raw
    os_raw="$(uname -s)"
    arch_raw="$(uname -m)"

    case "$os_raw" in
        Darwin) OS="macos" ;;
        Linux)
            # Check if running in WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                OS="linux"  # WSL runs Linux binaries
                log_info "Detected WSL environment"
            else
                OS="linux"
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            OS="windows"
            log_warn "For native Windows, consider using PowerShell instead:"
            echo -e "  ${INFO}iwr -useb https://raw.githubusercontent.com/$REPO/main/install.ps1 | iex${NC}"
            echo ""
            ;;
        *)
            log_error "Unsupported OS: $os_raw"
            echo "For native Windows (PowerShell):"
            echo "  iwr -useb https://raw.githubusercontent.com/$REPO/main/install.ps1 | iex"
            exit 1
            ;;
    esac

    case "$arch_raw" in
        x86_64|amd64) ARCH="x86_64" ;;
        arm64|aarch64) ARCH="aarch64" ;;
        *)
            log_error "Unsupported architecture: $arch_raw"
            exit 1
            ;;
    esac

    PLATFORM="${OS}-${ARCH}"
}

# ============================================================================
# Shell profile management
# ============================================================================

get_shell_rc() {
    # Return the appropriate shell rc file
    # bashrc works on most systems, but we also update zshrc for macOS
    if [[ "$OS" == "macos" ]]; then
        # macOS defaults to zsh, but we'll update both if they exist
        echo "$HOME/.zshrc"
    else
        echo "$HOME/.bashrc"
    fi
}

add_to_path_in_rc() {
    local dir="$1"
    local comment="$2"
    local path_line="export PATH=\"$dir:\$PATH\""
    
    # Files to update
    local rc_files=("$HOME/.bashrc")
    
    # Also add zshrc for macOS or if it exists
    if [[ "$OS" == "macos" ]] || [[ -f "$HOME/.zshrc" ]]; then
        rc_files+=("$HOME/.zshrc")
    fi
    
    # Also check .profile for broader compatibility
    if [[ -f "$HOME/.profile" ]]; then
        rc_files+=("$HOME/.profile")
    fi
    
    for rc in "${rc_files[@]}"; do
        # Create the file if it doesn't exist (especially bashrc)
        if [[ ! -f "$rc" ]]; then
            touch "$rc"
        fi
        
        # Only add if not already present
        if ! grep -q "$dir" "$rc" 2>/dev/null; then
            {
                echo ""
                echo "# $comment"
                echo "$path_line"
            } >> "$rc"
            log_info "Added ${INFO}$dir${NC} to ${INFO}$rc${NC}"
        fi
    done
}

refresh_path() {
    # Add directories to current PATH so user can use immediately
    export PATH="$INSTALL_DIR:$CARGO_BIN:$PATH"
}

add_alias_to_rc() {
    local alias_line="alias tt=\"timer_cli\""
    
    # Files to update
    local rc_files=("$HOME/.bashrc")
    
    if [[ "$OS" == "macos" ]] || [[ -f "$HOME/.zshrc" ]]; then
        rc_files+=("$HOME/.zshrc")
    fi
    
    for rc in "${rc_files[@]}"; do
        if [[ ! -f "$rc" ]]; then
            touch "$rc"
        fi
        
        # Only add if not already present
        if ! grep -q 'alias tt=' "$rc" 2>/dev/null; then
            {
                echo ""
                echo "# Terminal Timer (tt) CLI shortcut"
                echo "$alias_line"
            } >> "$rc"
            log_info "Added ${INFO}tt${NC} alias to ${INFO}$rc${NC}"
        fi
    done
    
    # Also set for current session
    alias tt="timer_cli"
}

# ============================================================================
# Homebrew (macOS)
# ============================================================================

check_homebrew() {
    command -v brew &> /dev/null
}

install_homebrew() {
    if [[ "$OS" != "macos" ]]; then
        return 0
    fi
    
    if check_homebrew; then
        log_success "Homebrew already installed"
        return 0
    fi
    
    log_warn "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    
    # Add Homebrew to PATH for this session
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
    
    log_success "Homebrew installed"
}

# ============================================================================
# Rust/Cargo installation
# ============================================================================

check_rust() {
    command -v cargo &> /dev/null
}

install_rust() {
    if check_rust; then
        log_success "Rust/Cargo already installed"
        return 0
    fi
    
    log_warn "Installing Rust via rustup (recommended)..."
    
    # Install via rustup (works on macOS and Linux, more reliable than brew)
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
    
    # Source cargo env for this session
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
    fi
    
    # Add cargo to shell profiles
    add_to_path_in_rc "$CARGO_BIN" "Rust/Cargo"
    
    log_success "Rust installed"
}

# ============================================================================
# Version resolution
# ============================================================================

get_latest_version() {
    local tmp_file
    tmp_file="$(mktempfile)"
    
    # Try GitHub API
    if download_file "https://api.github.com/repos/$REPO/releases/latest" "$tmp_file" 2>/dev/null; then
        local tag
        tag=$(grep '"tag_name":' "$tmp_file" 2>/dev/null | sed -E 's/.*"([^"]+)".*/\1/' | head -n1)
        if [[ -n "$tag" ]]; then
            echo "$tag"
            return 0
        fi
    fi
    
    # Fallback: scrape releases page
    if download_file "https://github.com/$REPO/releases" "$tmp_file" 2>/dev/null; then
        local tag
        tag=$(grep -oE "/releases/tag/[^\"']+" "$tmp_file" 2>/dev/null | head -n1 | sed 's|/releases/tag/||')
        if [[ -n "$tag" ]]; then
            echo "$tag"
            return 0
        fi
    fi
    
    return 1
}

# ============================================================================
# Installation methods
# ============================================================================

install_from_release() {
    local version="$1"
    local download_url tmp_file
    local binary_suffix=""
    
    [[ "$OS" == "windows" ]] && binary_suffix=".exe"
    
    download_url="https://github.com/$REPO/releases/download/${version}/${BINARY_NAME}-${PLATFORM}${binary_suffix}"
    
    log_warn "Downloading ${INFO}${BINARY_NAME}${NC} ${MUTED}(${version})${NC}..."
    
    tmp_file="$(mktempfile)"
    if ! download_file "$download_url" "$tmp_file" 2>/dev/null || [[ ! -s "$tmp_file" ]]; then
        return 1
    fi
    
    mkdir -p "$INSTALL_DIR"
    mv "$tmp_file" "${INSTALL_DIR}/${BINARY_NAME}${binary_suffix}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}${binary_suffix}"
    
    log_success "Downloaded and installed to ${INFO}${INSTALL_DIR}/${BINARY_NAME}${NC}"
    return 0
}

install_from_source() {
    log_warn "Building from source..."
    
    # Ensure Rust is installed
    if ! check_rust; then
        install_rust
    fi
    
    # Refresh PATH to pick up cargo
    refresh_path
    
    # Install via cargo
    log_warn "Running: cargo install --git https://github.com/$REPO.git"
    cargo install --git "https://github.com/$REPO.git"
    
    log_success "Built and installed via Cargo"
}

# ============================================================================
# Main
# ============================================================================

show_usage() {
    cat << EOF
Terminal Timer (tt) CLI Installer

Usage: 
    curl -fsSL https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/install.sh | bash
    ./install.sh [OPTIONS]

Options:
    -v, --version VERSION   Install a specific version (e.g., v1.0.5)
    -h, --help              Show this help message

Environment Variables:
    TIMER_CLI_INSTALL_DIR    Installation directory (default: ~/.local/bin)
    TIMER_CLI_BUILD_FROM_SOURCE  Set to 1 to build from source

Examples:
    # Install latest version
    curl -fsSL .../install.sh | bash

    # Install specific version
    curl -fsSL .../install.sh | bash -s -- --version v1.0.5
EOF
}

main() {
    local target_version=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -v|--version)
                target_version="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done

    echo -e "${BOLD}🕐 Terminal Timer (tt) CLI Installer${NC}"
    echo ""

    # Detect platform
    detect_platform
    log_success "Detected: ${INFO}${OS}${NC} (${ARCH})"

    # Ensure install directory exists
    mkdir -p "$INSTALL_DIR"

    # Add install directory to PATH in shell profiles
    add_to_path_in_rc "$INSTALL_DIR" "Terminal Timer (tt) CLI"

    # Try to install from release first
    local installed=0
    
    if [[ "$BUILD_FROM_SOURCE" != "1" ]]; then
        log_warn "Checking for pre-built release..."
        local version
        
        # Use specified version or get latest
        if [[ -n "$target_version" ]]; then
            version="$target_version"
            log_info "Installing specific version: ${INFO}${version}${NC}"
        else
            version=$(get_latest_version || true)
        fi
        
        if [[ -n "$version" ]]; then
            log_success "Found version: ${INFO}${version}${NC}"
            if install_from_release "$version"; then
                installed=1
            else
                log_warn "Pre-built binary not available for ${PLATFORM}"
            fi
        else
            log_warn "No releases found"
        fi
    fi

    # Fall back to building from source
    if [[ "$installed" == "0" ]]; then
        log_warn "Will build from source instead..."
        echo ""
        
        # Install Homebrew on macOS (might be needed for dependencies)
        if [[ "$OS" == "macos" ]]; then
            install_homebrew
        fi
        
        # Install Rust
        install_rust
        
        # Build from source
        install_from_source
    fi

    # Refresh PATH for current session
    refresh_path

    # Add tt alias to shell profiles
    add_alias_to_rc

    # Final success message
    echo ""
    echo -e "${SUCCESS}${BOLD}✅ Installation complete!${NC}"
    echo ""
    
    # Verify installation
    if command -v "$BINARY_NAME" &> /dev/null; then
        log_success "Ready to use! Try ${INFO}tt 5s \"Hello\"${NC} to test."
    else
        # Might need a new shell for PATH changes
        log_info "Open a new terminal, then try: ${INFO}tt 5s \"Hello\"${NC}"
    fi
    
    echo ""
    echo -e "Documentation: ${INFO}https://github.com/$REPO#readme${NC}"
}

main "$@"
