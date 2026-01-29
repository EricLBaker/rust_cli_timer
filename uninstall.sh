#!/bin/bash
set -euo pipefail

# Timer CLI Uninstaller for macOS, Linux, and Windows (WSL/Git Bash)
# Usage: curl -fsSL https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/uninstall.sh | bash
#
# For native Windows (PowerShell):
#   iwr -useb https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/uninstall.ps1 | iex

# ============================================================================
# Configuration
# ============================================================================

BINARY_NAME="timer_cli"
INSTALL_DIR="$HOME/.local/bin"
CARGO_BIN="$HOME/.cargo/bin"
REMOVE_RUST="${TIMER_CLI_REMOVE_RUST:-0}"

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
# Platform detection
# ============================================================================

OS=""
detect_platform() {
    local os_raw
    os_raw="$(uname -s)"
    case "$os_raw" in
        Darwin) OS="macos" ;;
        Linux)  OS="linux" ;;
        MINGW*|MSYS*|CYGWIN*)
            OS="windows"
            log_warn "For native Windows, consider using PowerShell instead:"
            echo -e "  ${INFO}iwr -useb https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/uninstall.ps1 | iex${NC}"
            echo ""
            ;;
        *)      OS="unknown" ;;
    esac
}

# ============================================================================
# Remove binary
# ============================================================================

remove_binary() {
    local removed=0
    
    # Check ~/.local/bin
    if [[ -f "${INSTALL_DIR}/${BINARY_NAME}" ]]; then
        rm -f "${INSTALL_DIR}/${BINARY_NAME}"
        log_success "Removed ${INFO}${INSTALL_DIR}/${BINARY_NAME}${NC}"
        removed=1
    fi
    
    # Check cargo bin (if installed via cargo install)
    if [[ -f "${CARGO_BIN}/${BINARY_NAME}" ]]; then
        rm -f "${CARGO_BIN}/${BINARY_NAME}"
        log_success "Removed ${INFO}${CARGO_BIN}/${BINARY_NAME}${NC}"
        removed=1
    fi
    
    # Try cargo uninstall if cargo is available
    if command -v cargo &> /dev/null; then
        if cargo uninstall "$BINARY_NAME" 2>/dev/null; then
            log_success "Uninstalled via cargo"
            removed=1
        fi
    fi
    
    if [[ "$removed" == "0" ]]; then
        log_warn "No ${BINARY_NAME} binary found to remove"
    fi
}

# ============================================================================
# Remove PATH entries from shell profiles
# ============================================================================

remove_from_rc() {
    local rc_file="$1"
    local pattern="$2"
    local comment_pattern="$3"
    
    if [[ ! -f "$rc_file" ]]; then
        return 0
    fi
    
    # Create a backup
    cp "$rc_file" "${rc_file}.bak"
    
    # Remove the PATH line and its comment
    local tmp_file
    tmp_file=$(mktemp)
    
    # Use grep to filter out matching lines (PATH and comment)
    grep -v "$pattern" "$rc_file" | grep -v "$comment_pattern" > "$tmp_file" || true
    
    # Remove extra blank lines that might be left behind
    cat -s "$tmp_file" > "$rc_file"
    rm -f "$tmp_file"
    
    log_success "Cleaned ${INFO}$rc_file${NC}"
}

clean_shell_profiles() {
    log_warn "Cleaning shell profiles..."
    
    local rc_files=("$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile")
    
    for rc in "${rc_files[@]}"; do
        if [[ -f "$rc" ]]; then
            # Remove Timer CLI PATH entry
            if grep -q "/.local/bin" "$rc" 2>/dev/null; then
                remove_from_rc "$rc" '\.local/bin' "# Timer CLI"
            fi
            
            # Remove Cargo PATH entry (only if we installed it)
            # We check for our specific comment to avoid removing user's own cargo config
            if grep -q "# Rust/Cargo" "$rc" 2>/dev/null; then
                remove_from_rc "$rc" '\.cargo/bin.*# Rust/Cargo\|# Rust/Cargo' "# Rust/Cargo"
            fi
        fi
    done
}

# ============================================================================
# Remove Rust (optional)
# ============================================================================

remove_rust() {
    if [[ "$REMOVE_RUST" != "1" ]]; then
        return 0
    fi
    
    if [[ -f "$HOME/.cargo/bin/rustup" ]]; then
        log_warn "Removing Rust installation..."
        "$HOME/.cargo/bin/rustup" self uninstall -y
        log_success "Rust uninstalled"
    elif command -v rustup &> /dev/null; then
        log_warn "Removing Rust installation..."
        rustup self uninstall -y
        log_success "Rust uninstalled"
    else
        log_warn "Rust/rustup not found, skipping"
    fi
}

# ============================================================================
# Remove app data (optional)
# ============================================================================

remove_app_data() {
    # Timer CLI stores history in SQLite - check common locations
    local data_locations=(
        "$HOME/.timer_cli"
        "$HOME/.local/share/timer_cli"
        "$HOME/.config/timer_cli"
    )
    
    local found=0
    for loc in "${data_locations[@]}"; do
        if [[ -e "$loc" ]]; then
            found=1
            break
        fi
    done
    
    if [[ "$found" == "1" ]]; then
        echo ""
        log_info "Found timer_cli data files. Remove them? (y/N)"
        read -r response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            for loc in "${data_locations[@]}"; do
                if [[ -e "$loc" ]]; then
                    rm -rf "$loc"
                    log_success "Removed ${INFO}$loc${NC}"
                fi
            done
        else
            log_info "Keeping data files"
        fi
    fi
}

# ============================================================================
# Argument parsing
# ============================================================================

print_usage() {
    cat <<EOF
Timer CLI Uninstaller

Usage:
  curl -fsSL https://raw.githubusercontent.com/EricLBaker/rust_cli_timer/main/uninstall.sh | bash
  ./uninstall.sh [options]

Options:
  --remove-rust    Also uninstall Rust (if it was installed by the installer)
  --help, -h       Show this help

Environment variables:
  TIMER_CLI_REMOVE_RUST=1    Also uninstall Rust

What this removes:
  • timer_cli binary from ~/.local/bin and ~/.cargo/bin
  • PATH entries added by the installer from shell profiles
  • Optionally: Rust installation (with --remove-rust)
  • Optionally: timer_cli data/history files (will prompt)

What this does NOT remove:
  • Homebrew (even if it was installed by the installer)
  • Any other tools or dependencies
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --remove-rust)
                REMOVE_RUST=1
                shift
                ;;
            --help|-h)
                print_usage
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo -e "${BOLD}🕐 Timer CLI Uninstaller${NC}"
    echo ""
    
    detect_platform
    
    # Remove the binary
    log_warn "Removing timer_cli binary..."
    remove_binary
    
    # Clean shell profiles
    clean_shell_profiles
    
    # Optionally remove Rust
    if [[ "$REMOVE_RUST" == "1" ]]; then
        remove_rust
    fi
    
    # Offer to remove app data
    remove_app_data
    
    echo ""
    echo -e "${SUCCESS}${BOLD}✅ Uninstallation complete!${NC}"
    echo ""
    log_info "You may need to restart your terminal for PATH changes to take effect."
    
    if [[ "$REMOVE_RUST" != "1" ]]; then
        echo ""
        log_info "Rust was not removed. To remove it, run:"
        echo -e "     ${INFO}rustup self uninstall${NC}"
        echo -e "  Or re-run with: ${INFO}./uninstall.sh --remove-rust${NC}"
    fi
}

parse_args "$@"
main
